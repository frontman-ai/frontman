defmodule FrontmanServerWeb.MCP.Server do
  @moduledoc false

  @server_name Mix.Project.config()[:app] |> Atom.to_string()
  @server_version Mix.Project.config()[:version]
  @input_keywords ~w(type description title default enum const minimum maximum minLength
                     maxLength minItems maxItems pattern format multipleOf exclusiveMinimum
                     exclusiveMaximum)

  use Anubis.Server, name: @server_name, version: @server_version, capabilities: [:tools]

  alias Anubis.MCP.Error
  alias Anubis.Server.{Component.Tool, Frame, Handlers, Response}
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Protocols.MCP.Schema
  alias FrontmanServer.WordPress

  @impl true
  def handle_request(%{"method" => method} = request, frame)
      when method in ["tools/list", "tools/call"] do
    previous = Map.fetch(frame.assigns, :mcp_request)

    {status, result, returned} =
      Handlers.handle(request, __MODULE__, Frame.assign(frame, :mcp_request, request))

    assigns =
      case previous do
        {:ok, value} -> Map.put(returned.assigns, :mcp_request, value)
        :error -> Map.delete(returned.assigns, :mcp_request)
      end

    {status, result, %{returned | assigns: assigns}}
  end

  def handle_request(request, frame), do: Handlers.handle(request, __MODULE__, frame)

  @impl true
  def server_tools(tools, frame) do
    fixed = [
      %Tool{
        name: "list_sites",
        description: "List WordPress sites connected to your Frontman account.",
        input_schema: %{"type" => "object", "properties" => %{}},
        validate_input: fn args -> {:ok, args} end
      }
      | tools
    ]

    with {:ok, scope} <- scope(frame),
         connections = WordPress.connections(scope),
         true <- permitted_discovery?(frame, connections) do
      selected =
        case frame.assigns.mcp_request do
          %{"method" => "tools/call", "params" => %{"arguments" => %{"site_id" => id}}} ->
            Ecto.UUID.cast!(id)

          _ ->
            nil
        end

      connections = Enum.sort_by(connections, &(&1.id != selected))
      Enum.sort_by(fixed ++ remote_tools(connections, Enum.map(fixed, & &1.name)), & &1.name)
    else
      _ -> fixed
    end
  end

  @impl true
  def handle_tool_call("list_sites", _arguments, frame) do
    case scope(frame) do
      {:ok, scope} ->
        sites = WordPress.list_sites(scope)
        {:reply, Response.json(Response.tool(), %{sites: sites}), frame}

      :error ->
        {:error, Error.execution("Account unavailable"), frame}
    end
  end

  def handle_tool_call(name, %{"site_id" => id} = arguments, frame) do
    with {:ok, scope} <- scope(frame),
         {:ok, result} <- WordPress.call(scope, id, name, Map.delete(arguments, "site_id")),
         {:ok, response} <- tool_response(result) do
      {:reply, response, frame}
    else
      _ -> {:error, Error.execution("WordPress tool unavailable"), frame}
    end
  end

  def tool_response(%{"resultType" => "complete", "content" => content} = result) do
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

  def tool_response(_), do: :error

  defp scope(frame) do
    with subject when is_binary(subject) <- Frame.subject(frame),
         {:ok, id} <- Ecto.UUID.cast(subject),
         user when not is_nil(user) <- Accounts.get_user(id) do
      {:ok, Scope.for_user(user)}
    else
      _ -> :error
    end
  end

  defp permitted_discovery?(%{assigns: %{mcp_request: %{"method" => "tools/list"}}}, _),
    do: true

  defp permitted_discovery?(
         %{
           assigns: %{
             mcp_request: %{
               "method" => "tools/call",
               "params" => %{
                 "arguments" => %{"site_id" => id}
               }
             }
           }
         },
         connections
       ) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> Enum.any?(connections, &(&1.id == id))
      :error -> false
    end
  end

  defp permitted_discovery?(_, _), do: false

  defp remote_tools(connections, reserved) do
    deadline = System.monotonic_time(:millisecond) + 6_000

    connections
    |> Task.async_stream(
      fn connection ->
        remaining = deadline - System.monotonic_time(:millisecond)
        result = if remaining > 0, do: WordPress.catalog(connection, remaining)
        {connection.id, result}
      end,
      max_concurrency: 32,
      ordered: false,
      timeout: 6_000,
      on_timeout: :kill_task
    )
    |> Stream.take_while(fn _ -> System.monotonic_time(:millisecond) < deadline end)
    |> Enum.flat_map(fn
      {:ok, {id, {:ok, %{"tools" => tools} = catalog}}} ->
        with true <- Map.get(catalog, "resultType", "complete") == "complete",
             true <- Schema.bounded?(catalog),
             :ok <-
               Schema.validate_tools_list_envelope(
                 Map.merge(
                   %{
                     "resultType" => "complete",
                     "ttlMs" => 0,
                     "cacheScope" => "private"
                   },
                   catalog
                 )
               ) do
          Enum.map(tools, &{id, &1})
        else
          _ -> []
        end

      _ ->
        []
    end)
    |> catalog_tools(reserved)
  end

  def catalog_tools(entries, reserved) do
    entries
    |> Enum.group_by(fn {_, tool} -> tool["name"] end)
    |> Enum.flat_map(fn {name, entries} ->
      entries = Enum.sort_by(entries, &elem(&1, 0))

      schemas =
        Enum.map(entries, fn {_, tool} -> Map.take(tool, ["inputSchema", "outputSchema"]) end)

      {_, tool} = hd(entries)
      ids = Enum.map(entries, &elem(&1, 0))

      if name not in reserved and length(Enum.uniq(schemas)) == 1 and
           supported_input?(tool["inputSchema"]) do
        [remote_tool(tool, ids)]
      else
        []
      end
    end)
  end

  defp remote_tool(tool, ids) do
    schema = tool["inputSchema"]
    properties = Map.get(schema, "properties", %{})

    schema =
      schema
      |> Map.put("properties", Map.put(properties, "site_id", %{"type" => "string"}))
      |> Map.put("required", ["site_id" | Map.get(schema, "required", [])])

    %Tool{
      name: tool["name"],
      title: tool["title"],
      description: tool["description"],
      input_schema: schema,
      output_schema: tool["outputSchema"],
      annotations: tool["annotations"],
      icons: tool["icons"],
      meta: tool["_meta"],
      validate_input: fn
        %{"site_id" => id} = args ->
          case Ecto.UUID.cast(id) do
            {:ok, id} -> if id in ids, do: {:ok, args}, else: {:error, ["Site unavailable"]}
            _ -> {:error, ["Site unavailable"]}
          end

        _ ->
          {:error, ["Site unavailable"]}
      end,
      validate_output: fn output -> {:ok, output} end
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
