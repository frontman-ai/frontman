defmodule FrontmanServerWeb.TasksChannel do
  @moduledoc """
  Channel for Tasks management.

  Handles protocol initialization and session creation.
  Clients join this channel first, then join session-specific
  channels after creating a session.
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias AgentClientProtocol, as: ACP
  alias FrontmanServer.Tasks

  @acp_protocol_version ACP.protocol_version()

  @impl true
  def join("tasks", _params, socket) do
    Logger.info("Client joining tasks channel")
    socket = assign(socket, :acp_initialized, false)
    {:ok, %{status: "connected"}, socket}
  end

  @impl true
  def handle_in("acp:message", payload, socket) do
    case JsonRpc.parse(payload) do
      {:ok, message} -> handle_message(message, socket)
      {:error, reason} -> handle_parse_error(reason, payload, socket)
    end
  end

  # Initialize with correct protocol version
  defp handle_message(
         {:request, id, "initialize", %{"protocolVersion" => @acp_protocol_version} = params},
         socket
       ) do
    Logger.info("ACP initialize from #{inspect(params["clientInfo"])}")

    socket =
      socket
      |> assign(:acp_initialized, true)
      |> assign(:acp_client_info, params["clientInfo"])
      |> assign(:acp_client_capabilities, params["clientCapabilities"])

    push_response(socket, id, ACP.build_initialize_result())
  end

  defp handle_message({:request, id, "initialize", %{"protocolVersion" => _}}, socket) do
    push_error(socket, id, JsonRpc.error_invalid_request(), "Unsupported protocol version")
  end

  defp handle_message({:request, id, "initialize", _params}, socket) do
    push_error(
      socket,
      id,
      JsonRpc.error_invalid_params(),
      "Missing required field: protocolVersion"
    )
  end

  # Create new session
  defp handle_message({:request, id, "session/new", _params}, socket) do
    Logger.info("ACP session/new request received")

    case extract_framework(socket.assigns[:acp_client_info]) do
      nil ->
        push_error(socket, id, JsonRpc.error_invalid_params(), "Missing framework in clientInfo")

      framework ->
        scope = socket.assigns.scope
        task_id = ACP.generate_session_id()
        {:ok, ^task_id} = Tasks.create_task(scope, task_id, framework)
        push_response(socket, id, ACP.build_session_new_result(task_id))
    end
  end

  # Unknown method
  defp handle_message({:request, id, method, _params}, socket) do
    Logger.info("ACP unknown method: #{method}")
    push_error(socket, id, JsonRpc.error_method_not_found(), "Method not found")
  end

  defp handle_message({:notification, _method, _params}, socket) do
    {:noreply, socket}
  end

  defp extract_framework(nil), do: nil
  defp extract_framework(client_info) when is_map(client_info), do: Map.get(client_info, "name")
  defp extract_framework(_), do: nil

  # Parse errors
  defp handle_parse_error(reason, %{"id" => id}, socket) do
    Logger.error("Invalid ACP message: #{inspect(reason)}")
    push_error(socket, id, JsonRpc.error_invalid_request(), "Invalid JSON-RPC message")
  end

  defp handle_parse_error(reason, payload, socket) do
    Logger.error("Invalid ACP message: #{inspect(reason)}, payload: #{inspect(payload)}")
    {:noreply, socket}
  end

  defp push_response(socket, id, result) do
    push(socket, "acp:message", JsonRpc.success_response(id, result))
    {:noreply, socket}
  end

  defp push_error(socket, id, code, message) do
    push(socket, "acp:message", JsonRpc.error_response(id, code, message))
    {:noreply, socket}
  end
end
