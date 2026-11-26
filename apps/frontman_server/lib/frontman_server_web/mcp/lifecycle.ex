defmodule FrontmanServerWeb.MCP.Lifecycle do
  @moduledoc """
  Observes authenticated initialize at the HTTP boundary, not the tool handler.

  Anubis handles initialize inside its session and may return a JSON-RPC error
  with HTTP 200, including over SSE. Completion means the response was accepted
  by the HTTP adapter, not that the client received it or sent initialized.
  """

  alias FrontmanServer.Analytics
  alias FrontmanServerWeb.MCP.{ConsentIdentity, LifecycleAdapter}

  # Validator and adapter callbacks execute in this request process. Never carry
  # tokens or rejected claims across that boundary; always remove scoped state.
  def call(conn, dispatch) do
    if Analytics.config()[:enabled] == true do
      observe(conn, dispatch)
    else
      dispatch.(conn)
    end
  end

  defp observe(conn, dispatch) do
    Process.put(__MODULE__, %{body: conn.body_params, method: conn.method})
    {adapter, payload} = conn.adapter

    try do
      result = dispatch.(%{conn | adapter: {LifecycleAdapter, {adapter, payload}}})
      finish_authentication(result)
      complete("unknown", "response_unobserved")
      %{result | adapter: unwrap(result.adapter)}
    catch
      kind, reason ->
        complete("unknown", "request_interrupted")
        :erlang.raise(kind, reason, __STACKTRACE__)
    after
      Process.delete(__MODULE__)
    end
  end

  def authenticated(user_id, client_id, verified_claims) do
    case Process.get(__MODULE__) do
      %{} = state ->
        properties =
          verified_claims
          |> ConsentIdentity.properties()
          |> Map.merge(%{
            user_id: user_id,
            entry_surface: "mcp",
            mcp_client: client_label(client_id)
          })

        <<uuid::binary-size(16), _::binary>> =
          :crypto.hash(:sha256, "mcp_client_connected:" <> user_id <> ":" <> client_id)

        Process.put(
          __MODULE__,
          Map.merge(state, %{
            properties: properties,
            connection_event_id: Ecto.UUID.load!(uuid),
            authenticated_at: System.monotonic_time(:millisecond)
          })
        )

      nil ->
        :ok
    end
  end

  def authentication_failed(reason) do
    case Process.get(__MODULE__) do
      %{} = state -> Process.put(__MODULE__, Map.put(state, :auth_failure, reason))
      nil -> :ok
    end
  end

  def request(body) when is_binary(body) and byte_size(body) <= 1_048_576 do
    case Jason.decode(body) do
      {:ok, decoded} -> request(decoded)
      {:error, _} -> :ok
    end
  end

  def request(%{"jsonrpc" => "2.0", "method" => "initialize", "id" => id})
      when is_integer(id) or is_binary(id) do
    case Process.get(__MODULE__) do
      %{method: "POST", properties: properties} = state ->
        unless Map.has_key?(state, :started) do
          properties = Map.put(properties, :request_id, Ecto.UUID.generate())

          Analytics.track(
            "mcp_client_connected",
            Map.put(properties, :event_id, state.connection_event_id)
          )

          Analytics.track("mcp_initialize_received", properties)

          Process.put(
            __MODULE__,
            Map.merge(state, %{
              properties: properties,
              started: state.authenticated_at
            })
          )
        end

      _ ->
        :ok
    end
  end

  def request(_body), do: :ok

  # For bodies already parsed by Phoenix, admission waits until the transport
  # confirms authorization. Anubis rechecks expiry after our validator returns.
  def response_started(401), do: :ok

  def response_started(_status) do
    case Process.get(__MODULE__) do
      %{body: body} -> request(body)
      _ -> :ok
    end
  end

  def response(status, _body) when status >= 400,
    do: complete("failed", "http_rejected")

  def response(_status, body), do: response(body)

  def response(body) do
    case Process.get(__MODULE__) do
      %{started: _} ->
        if IO.iodata_length(body) <= 1_048_576 do
          body |> IO.iodata_to_binary() |> decode_response()
        else
          complete("unknown", "response_too_large")
        end

      _ ->
        :ok
    end
  end

  def chunk(body, result) do
    case Process.get(__MODULE__) do
      %{started: _} -> observe_chunk(body, result)
      _ -> :ok
    end
  end

  defp observe_chunk(body, result) do
    case result do
      {:error, _} ->
        complete("unknown", "transport_failed")

      _ ->
        # Anubis sends one complete JSON-RPC SSE event per chunk.
        if IO.iodata_length(body) <= 1_048_576 do
          body
          |> IO.iodata_to_binary()
          |> String.split("\n")
          |> Enum.each(&observe_sse_line/1)
        else
          complete("unknown", "response_too_large")
        end
    end
  end

  defp observe_sse_line("data: " <> data), do: response(data)
  defp observe_sse_line(_line), do: :ok

  defp decode_response(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => %{"code" => _}}} ->
        complete("failed", "protocol_error")

      {:ok, %{"result" => %{"protocolVersion" => _, "serverInfo" => _, "capabilities" => _}}} ->
        complete("succeeded", "initialize_result")

      _ ->
        complete("unknown", "response_unrecognized")
    end
  end

  defp complete(outcome, reason) do
    case Process.get(__MODULE__) do
      %{started: started, properties: properties} = state ->
        Process.put(__MODULE__, Map.delete(state, :started))

        Analytics.track(
          "mcp_initialize_completed",
          Map.merge(properties, %{
            outcome: outcome,
            reason_code: reason,
            duration_ms: System.monotonic_time(:millisecond) - started
          })
        )

      _ ->
        :ok
    end
  end

  defp finish_authentication(%{status: 401} = conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      [] ->
        :ok

      _ ->
        reason = authentication_reason(Process.get(__MODULE__))
        # One anonymous diagnostic per category per minute, not a user/attempt
        # count. Attacker-controlled claims never influence identity or volume.
        bucket = div(System.system_time(:second), 60)

        <<uuid::binary-size(16), _::binary>> =
          :crypto.hash(:sha256, "mcp_authentication_failed:#{bucket}:#{reason}")

        id = Ecto.UUID.load!(uuid)

        Analytics.track("mcp_authentication_failed", %{
          event_id: id,
          diagnostic_bucket_id: id,
          identity_kind: "unattributed",
          entry_surface: "mcp",
          mcp_client: "unknown",
          outcome: "failed",
          reason_code: Atom.to_string(reason)
        })
    end
  end

  defp finish_authentication(_conn), do: :ok

  defp authentication_reason(%{auth_failure: reason}), do: reason
  defp authentication_reason(%{properties: _}), do: :authentication_rejected
  defp authentication_reason(_state), do: :malformed_authorization

  defp client_label(client_id) do
    label =
      case Analytics.config()[:mcp_clients] do
        %{} = clients -> Map.get(clients, client_id)
        _ -> nil
      end

    case label do
      label when is_binary(label) and byte_size(label) <= 64 ->
        if Regex.match?(~r/\A[a-z0-9_-]+\z/, label), do: label, else: "unknown"

      _ ->
        "unknown"
    end
  end

  defp unwrap({LifecycleAdapter, adapter}), do: adapter
end
