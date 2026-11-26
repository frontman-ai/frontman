defmodule FrontmanServerWeb.MCP.Server do
  @moduledoc false

  @server_name Mix.Project.config()[:app] |> Atom.to_string()
  @server_version Mix.Project.config()[:version]
  @security_schemes [%{"type" => "oauth2", "scopes" => []}]
  @input_keywords ~w(type description title default enum const minimum maximum minLength
                     maxLength minItems maxItems pattern format multipleOf exclusiveMinimum
                     exclusiveMaximum minProperties maxProperties)

  use Anubis.Server, name: @server_name, version: @server_version, capabilities: [:tools]

  alias Anubis.MCP.Error
  alias Anubis.Server.{Component.Tool, Frame, Handlers, Response}
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Analytics
  alias FrontmanServer.Billing
  alias FrontmanServer.Protocols.MCP.Schema
  alias FrontmanServer.WordPress
  alias FrontmanServer.WordPress.Onboarding
  alias FrontmanServerWeb.Endpoint
  alias FrontmanServerWeb.MCP.ConsentIdentity

  @impl true
  def handle_request(%{"method" => method} = request, frame)
      when method in ["tools/list", "tools/call"] do
    case resolve_scope(frame) do
      {:ok, scope} ->
        started_at = System.monotonic_time(:millisecond)
        track_connected(scope, frame)
        result = authorized_tools_request(request, frame, scope)
        track_completed(scope, request, result, started_at)
        result

      :error ->
        {:error, Error.execution("Account unavailable"), frame}
    end
  end

  def handle_request(request, frame), do: Handlers.handle(request, __MODULE__, frame)

  defp authorized_tools_request(request, frame, scope) do
    case Billing.subscription_access(scope) do
      {:allowed, _} ->
        handle_tools_request(request, frame, scope)

      _ ->
        {:error,
         Error.execution("An active subscription or eligible trial is required for hosted MCP"),
         frame}
    end
  end

  # Authenticated client IDs identify registrations, not brands. Never infer a
  # brand from clientInfo, an auth provider, or a redirect URL.
  defp track_connected(scope, %{context: %{auth: %{client_id: client_id}}} = frame)
       when is_binary(client_id) do
    <<uuid::binary-size(16), _::binary>> =
      :crypto.hash(:sha256, "mcp_client_connected:" <> scope.user.id <> ":" <> client_id)

    track(scope, "mcp_client_connected", %{event_id: Ecto.UUID.load!(uuid)}, frame)
  end

  defp track_connected(_scope, _frame), do: :ok

  defp track_completed(scope, request, {status, result, frame}, started_at) do
    properties = %{
      outcome: completion_outcome(status, result),
      duration_ms: System.monotonic_time(:millisecond) - started_at
    }

    case request do
      %{"method" => "tools/list"} ->
        track(scope, "mcp_tools_list_completed", properties, frame)

      %{"method" => "tools/call", "params" => %{"name" => "list_sites"}} ->
        track(
          scope,
          "mcp_tool_call_completed",
          Map.put(properties, :tool_name, "list_sites"),
          frame
        )

      %{"method" => "tools/call"} ->
        track(
          scope,
          "mcp_tool_call_completed",
          Map.put(properties, :operation_kind, "unknown"),
          frame
        )
    end
  end

  defp completion_outcome(:reply, %Response{isError: true}), do: "failed"
  defp completion_outcome(:reply, %Response{isError: false}), do: "succeeded"

  defp completion_outcome(:reply, result) do
    if Map.get(result, "isError", false), do: "failed", else: "succeeded"
  end

  defp completion_outcome(:error, _result), do: "failed"

  defp track(scope, event, properties, frame) do
    Analytics.track(
      event,
      properties
      |> Map.merge(consent_properties(frame))
      |> Map.merge(%{
        user_id: scope.user.id,
        entry_surface: "mcp",
        mcp_client: client_label(frame)
      })
    )
  end

  defp client_label(%{context: %{auth: %{client_id: client_id}}}) when is_binary(client_id) do
    case Analytics.config()[:mcp_clients] do
      %{} = clients ->
        clients |> Map.get(client_id) |> safe_client_label()

      _ ->
        "unknown"
    end
  end

  defp client_label(_frame), do: "unknown"

  defp safe_client_label(label) when is_binary(label) and byte_size(label) <= 64 do
    if Regex.match?(~r/\A[a-z0-9_-]+\z/, label), do: label, else: "unknown"
  end

  defp safe_client_label(_label), do: "unknown"

  defp handle_tools_request(%{"method" => method} = request, frame, scope) do
    previous = Map.take(frame.assigns, [:mcp_catalog, :current_scope])
    frame = Frame.assign(frame, :current_scope, scope)

    {status, result, returned} =
      case discover(request, frame) do
        {:ok, catalog} ->
          Handlers.handle(request, __MODULE__, Frame.assign(frame, :mcp_catalog, catalog))

        {:error, error} ->
          {:error, error, frame}
      end

    assigns =
      returned.assigns
      |> Map.drop([:mcp_catalog, :current_scope])
      |> Map.merge(previous)

    {status, tool_list_result(method, status, result), %{returned | assigns: assigns}}
  end

  defp discover(%{"method" => "tools/call", "params" => %{"name" => "list_sites"}}, _frame),
    do: {:ok, []}

  defp discover(request, frame) do
    case scope(frame) do
      {:ok, scope} ->
        connections = discovery_connections(request, WordPress.list_sites(scope))

        case {request["method"], connections} do
          {"tools/call", []} -> {:error, invalid_site_error()}
          _ -> remote_tools(scope, connections)
        end

      :error ->
        {:error, Error.execution("Account unavailable")}
    end
  end

  defp invalid_site_error do
    Error.protocol(:invalid_params, %{
      message:
        "Call list_sites and pass an accessible site's id as site_id. " <>
          "If no sites are listed, connect a WordPress site first."
    })
  end

  @impl true
  def server_tools(tools, frame) do
    fixed = [
      %Tool{
        name: "list_sites",
        title: "List WordPress Sites",
        description:
          "List connected WordPress sites for a requested WordPress task. If none are connected, guide the user through setup.",
        input_schema: %{"type" => "object", "properties" => %{}},
        annotations: %{
          "readOnlyHint" => true,
          "destructiveHint" => false,
          "openWorldHint" => false,
          "idempotentHint" => true
        },
        validate_input: fn args -> {:ok, args} end
      }
      | tools
    ]

    Enum.sort_by(
      fixed ++ catalog_tools(Map.get(frame.assigns, :mcp_catalog, []), Enum.map(fixed, & &1.name)),
      & &1.name
    )
  end

  @impl true
  def handle_tool_call("list_sites", _arguments, frame) do
    case scope(frame) do
      {:ok, scope} ->
        sites = WordPress.list_sites(scope)

        track(
          scope,
          "mcp_sites_list_completed",
          %{outcome: "succeeded", count: length(sites)},
          frame
        )

        result =
          case sites do
            [] ->
              %{
                sites: [],
                status: "connection_required",
                explanation:
                  "No WordPress sites are connected to this Frontman account. Guide the user through connecting a site; do not attempt WordPress edits yet.",
                connection_url: Endpoint.url() <> "/wordpress/connect",
                next_steps:
                  Onboarding.steps() ++
                    ["Run list_sites again to confirm the connection before editing."]
              }

            _ ->
              %{sites: sites}
          end

        {:reply, Response.json(Response.tool(), result), frame}

      :error ->
        {:error, Error.execution("Account unavailable"), frame}
    end
  end

  def handle_tool_call(name, %{"site_id" => id} = arguments, frame) do
    with {:ok, scope} <- scope(frame),
         {:ok, result} <- WordPress.call(scope, id, name, Map.delete(arguments, "site_id")),
         {:ok, response} <- tool_response(result) do
      if response.isError == false do
        {:ok, :ok} = Accounts.record_activation(scope)

        # Remote annotations are hints, not verified read/mutation semantics.
        # Discovery never enters this branch: tools/list and list_sites are separate.
        Analytics.record_mcp_activation(
          scope,
          authenticated_client_id(frame),
          Map.put(consent_properties(frame), :mcp_client, client_label(frame))
        )
      end

      {:reply, response, frame}
    else
      _ -> {:error, Error.execution("WordPress tool unavailable"), frame}
    end
  end

  defp tool_list_result("tools/list", :reply, result) do
    tools =
      result
      |> Map.fetch!("tools")
      |> JSON.encode!()
      |> JSON.decode!()
      |> Enum.map(fn tool ->
        tool
        |> Map.put("securitySchemes", @security_schemes)
        |> Map.update("_meta", %{"securitySchemes" => @security_schemes}, fn meta ->
          Map.put(meta, "securitySchemes", @security_schemes)
        end)
      end)

    Map.put(result, "tools", tools)
  end

  defp tool_list_result(_method, _status, result), do: result

  defp tool_response(%{"resultType" => "complete", "content" => content} = result) do
    with true <- Schema.bounded?(result),
         :ok <- Schema.validate_call_tool_result(result) do
      {:ok,
       %Response{
         type: :tool,
         content: content,
         isError: Map.get(result, "isError", false),
         structured_content: result["structuredContent"],
         meta: result["_meta"]
       }}
    else
      _ -> :error
    end
  end

  defp tool_response(_), do: :error

  defp scope(%Frame{assigns: %{current_scope: %Scope{} = scope}}), do: {:ok, scope}
  defp scope(_frame), do: :error

  defp authenticated_client_id(%{context: %{auth: %{client_id: client_id}}}), do: client_id
  defp authenticated_client_id(_frame), do: nil

  defp consent_properties(%{context: %{auth: auth}}),
    do: ConsentIdentity.properties(auth)

  defp consent_properties(_frame), do: %{}

  defp resolve_scope(frame) do
    with subject when is_binary(subject) <- Frame.subject(frame),
         {:ok, id} <- Ecto.UUID.cast(subject),
         user when not is_nil(user) <- Accounts.get_user(id) do
      {:ok, Scope.for_user(user)}
    else
      _ -> :error
    end
  end

  defp discovery_connections(%{"method" => "tools/list"}, connections), do: connections

  defp discovery_connections(
         %{"method" => "tools/call", "params" => %{"arguments" => %{"site_id" => id}}},
         connections
       ) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Enum.filter(connections, &(&1.id == id))
      :error -> []
    end
  end

  defp discovery_connections(_, _), do: []

  defp remote_tools(scope, connections) do
    case WordPress.discover_tools(scope, Enum.map(connections, & &1.id)) do
      {:ok, entries} -> {:ok, entries}
      {:error, _category} -> {:error, Error.execution("WordPress catalog unavailable")}
    end
  end

  def catalog_tools(entries, reserved) do
    entries
    |> Enum.group_by(fn {_, tool} -> tool["name"] end)
    |> Enum.flat_map(fn {name, entries} ->
      {_, tool} = Enum.min_by(entries, &elem(&1, 0))

      compatible =
        Enum.all?(entries, fn
          {_, %{"outputSchema" => _}} -> false
          {_, candidate} -> candidate["inputSchema"] === tool["inputSchema"]
        end)

      with false <- name in reserved,
           true <- compatible,
           true <- supported_input?(tool["inputSchema"]) do
        [remote_tool(tool)]
      else
        _ -> []
      end
    end)
  end

  defp remote_tool(tool) do
    schema = tool["inputSchema"]
    properties = Map.get(schema, "properties", %{})

    schema =
      schema
      |> Map.put(
        "properties",
        Map.put(properties, "site_id", %{
          "type" => "string",
          "description" =>
            "The connected site's id returned by list_sites. Call list_sites first; do not use a URL or WordPress post ID."
        })
      )
      |> Map.put("required", ["site_id" | Map.get(schema, "required", [])])

    %Tool{
      name: tool["name"],
      title: tool["title"],
      description: tool["description"],
      input_schema: schema,
      annotations: tool["annotations"],
      icons: tool["icons"],
      meta: tool["_meta"],
      validate_input: fn args -> {:ok, args} end
    }
  end

  def supported_input?(%{"type" => "object"} = schema) do
    properties = Map.get(schema, "properties", %{})
    required = Map.get(schema, "required", [])

    is_map(properties) and is_list(required) and "site_id" not in required and
      not Map.has_key?(properties, "site_id") and not Map.has_key?(schema, "const") and
      not Map.has_key?(schema, "enum") and safe_schema?(schema) and
      Schema.validate_input_metadata(schema) == :ok
  end

  def supported_input?(_), do: false

  defp safe_schema?(schema) when is_map(schema) do
    Enum.all?(schema, fn
      {"properties", properties} when is_map(properties) ->
        Enum.all?(properties, fn {_, child} -> safe_schema?(child) end)

      {"items", child} ->
        safe_schema?(child)

      {"required", required} when is_list(required) ->
        Enum.all?(required, &is_binary/1)

      {"additionalProperties", value} ->
        is_boolean(value)

      {key, _} when key in @input_keywords ->
        true

      _ ->
        false
    end)
  end

  defp safe_schema?(_), do: false
end
