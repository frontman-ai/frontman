defmodule FrontmanServerWeb.SessionsChannel do
  @moduledoc """
  Channel for ACP session management.

  Handles protocol initialization and session creation.
  Clients join this channel first, then join session-specific
  channels after creating a session.
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias FrontmanServerWeb.ACP
  alias FrontmanServer.Tasks
  alias FrontmanServerWeb.JsonRpc

  @acp_protocol_version ACP.protocol_version()

  @impl true
  def join("sessions", _params, socket) do
    Logger.info("Client joining sessions channel")
    socket = assign(socket, :acp_initialized, false)
    {:ok, %{status: "connected"}, socket}
  end

  @impl true
  def handle_in("acp:message", payload, socket) do
    case JsonRpc.parse(payload) do
      {:ok, {:request, id, "initialize", params}} ->
        handle_initialize(id, params, socket)

      {:ok, {:request, id, "session/new", _params}} ->
        handle_session_new(id, socket)

      {:ok, {:request, id, method, _params}} ->
        Logger.info("ACP unknown method: #{method}")
        push_error(socket, id, JsonRpc.error_method_not_found(), "Method not found")

      {:ok, {:notification, _method, _params}} ->
        {:noreply, socket}

      {:error, reason} ->
        Logger.error(
          "Invalid ACP message in sessions channel: #{inspect(reason)}, payload: #{inspect(payload)}"
        )

        # If payload has an id, send error response; otherwise ignore (can't respond to malformed request)
        case payload do
          %{"id" => id} ->
            error_response =
              JsonRpc.error_response(id, JsonRpc.error_invalid_request(), "Invalid JSON-RPC message")

            push(socket, "acp:message", error_response)
            {:noreply, socket}

          _ ->
            {:noreply, socket}
        end
    end
  end

  defp handle_initialize(id, params, socket) do
    case params do
      %{"protocolVersion" => @acp_protocol_version} ->
        Logger.info("ACP initialize from #{inspect(params["clientInfo"])}")

        socket =
          socket
          |> assign(:acp_initialized, true)
          |> assign(:acp_client_info, params["clientInfo"])
          |> assign(:acp_client_capabilities, params["clientCapabilities"])

        response = JsonRpc.success_response(id, ACP.build_initialize_result())
        push(socket, "acp:message", response)
        {:noreply, socket}

      %{"protocolVersion" => _wrong_version} ->
        push_error(socket, id, JsonRpc.error_invalid_request(), "Unsupported protocol version")

      _ ->
        push_error(
          socket,
          id,
          JsonRpc.error_invalid_params(),
          "Missing required field: protocolVersion"
        )
    end
  end

  defp handle_session_new(id, socket) do
    Logger.info("ACP session/new request received")
    session_id = ACP.generate_session_id()
    {:ok, ^session_id} = Tasks.create_task(session_id, %{})

    response = JsonRpc.success_response(id, ACP.build_session_new_result(session_id))
    push(socket, "acp:message", response)
    {:noreply, socket}
  end

  defp push_error(socket, id, code, message) do
    response = JsonRpc.error_response(id, code, message)
    push(socket, "acp:message", response)
    {:noreply, socket}
  end
end
