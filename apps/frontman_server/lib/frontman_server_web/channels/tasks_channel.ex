defmodule FrontmanServerWeb.TasksChannel do
  @moduledoc """
  Channel for Tasks management.

  Handles protocol initialization and session creation.
  Clients join this channel first, then join session-specific
  channels after creating a session.
  """
  use FrontmanServerWeb, :channel
  use FrontmanServerWeb, :verified_routes
  require Logger

  alias AgentClientProtocol, as: ACP
  alias FrontmanServer.Providers.Registry
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.Framework
  alias FrontmanServerWeb.ACPHistory

  @acp_protocol_version ACP.protocol_version()

  @impl true
  def join("tasks", _params, socket) do
    if Map.has_key?(socket.assigns, :scope) do
      Logger.info("Client joining tasks channel (authenticated)")

      # Subscribe to title updates for this user
      Phoenix.PubSub.subscribe(
        FrontmanServer.PubSub,
        Tasks.title_pubsub_topic(socket.assigns.scope.user.id)
      )

      socket = assign(socket, :acp_initialized, false)
      {:ok, %{status: "connected"}, socket}
    else
      Logger.info("Client joining tasks channel (unauthenticated)")
      {:error, %{reason: "unauthorized", login_url: url(~p"/users/log-in")}}
    end
  end

  @impl true
  def handle_in("acp:message", payload, socket) do
    case JsonRpc.parse(payload) do
      {:ok, message} -> handle_message(message, socket)
      {:error, reason} -> handle_parse_error(reason, payload, socket)
    end
  end

  # Non-ACP channel event for listing sessions
  @impl true
  def handle_in("list_sessions", _payload, socket) do
    scope = socket.assigns.scope
    {:ok, tasks} = Tasks.list_tasks(scope)

    sessions =
      Enum.map(tasks, fn task ->
        %{
          "sessionId" => task.id,
          "title" => task.short_desc,
          "createdAt" => DateTime.to_iso8601(task.inserted_at),
          "updatedAt" => DateTime.to_iso8601(task.updated_at)
        }
      end)

    {:reply, {:ok, %{"sessions" => sessions}}, socket}
  end

  # Non-ACP channel event for deleting a session
  @impl true
  def handle_in("delete_session", %{"sessionId" => session_id}, socket) do
    case Tasks.delete_task(socket.assigns.scope, session_id) do
      :ok -> {:reply, {:ok, %{}}, socket}
      {:error, reason} -> {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  # No catch-all handler - let it crash on malformed requests (zero silent failures)

  # Initialize with correct protocol version
  defp handle_message(
         {:request, id, "initialize", %{"protocolVersion" => @acp_protocol_version} = params},
         socket
       ) do
    Logger.info("ACP initialize from #{inspect(params["clientInfo"])}")

    # Extract env API key from clientInfo metadata (if provided by the project)
    env_api_key = extract_env_api_key(params["clientInfo"])

    socket =
      socket
      |> assign(:acp_initialized, true)
      |> assign(:acp_client_info, params["clientInfo"])
      |> assign(:acp_client_capabilities, params["clientCapabilities"])
      |> assign(:env_api_key, env_api_key)

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

  # Create new session (client provides sessionId)
  defp handle_message({:request, id, "session/new", %{"sessionId" => session_id}}, socket)
       when is_binary(session_id) and session_id != "" do
    Logger.info("ACP session/new request received with sessionId: #{session_id}")

    with :ok <- validate_uuid_format(session_id),
         raw_framework when is_binary(raw_framework) <-
           extract_framework(socket.assigns[:acp_client_info]),
         fw = Framework.from_client_label(raw_framework),
         {:ok, ^session_id} <-
           Tasks.create_task(
             socket.assigns.scope,
             session_id,
             Framework.to_string(fw)
           ) do
      push_response(socket, id, ACP.build_session_new_result(session_id))
    else
      :error ->
        push_error(
          socket,
          id,
          JsonRpc.error_invalid_params(),
          "Invalid sessionId: must be a valid UUID"
        )

      nil ->
        push_error(socket, id, JsonRpc.error_invalid_params(), "Missing framework in clientInfo")

      {:error, _changeset} ->
        push_error(socket, id, JsonRpc.error_invalid_params(), "Failed to create session")
    end
  end

  defp handle_message({:request, id, "session/new", _params}, socket) do
    push_error(socket, id, JsonRpc.error_invalid_params(), "Missing required field: sessionId")
  end

  # ACP session/load - streams history via session/update notifications
  defp handle_message(
         {:request, id, "session/load", %{"sessionId" => session_id} = _params},
         socket
       ) do
    Logger.info("ACP session/load request received for session: #{session_id}")
    scope = socket.assigns.scope

    case Tasks.get_task(scope, session_id) do
      {:ok, task} ->
        # Stream history via session/update notifications
        stream_session_history(socket, task)
        # Return ACP-compliant response
        push_response(socket, id, %{})

      {:error, :not_found} ->
        push_error(socket, id, JsonRpc.error_invalid_params(), "Session not found")
    end
  end

  defp handle_message({:request, id, "session/load", _params}, socket) do
    push_error(socket, id, JsonRpc.error_invalid_params(), "Missing sessionId parameter")
  end

  # Unknown method
  defp handle_message({:request, id, method, _params}, socket) do
    Logger.info("ACP unknown method: #{method}")
    push_error(socket, id, JsonRpc.error_method_not_found(), "Method not found")
  end

  defp handle_message({:notification, _method, _params}, socket) do
    {:noreply, socket}
  end

  # Handle title update broadcasts from TitleGenerator
  @impl true
  def handle_info({:title_updated, task_id, title}, socket) do
    push(socket, "title_updated", %{"sessionId" => task_id, "title" => title})
    {:noreply, socket}
  end

  # UUID v4 format: 8-4-4-4-12 hex digits with dashes
  @uuid_regex ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  defp validate_uuid_format(string) do
    if Regex.match?(@uuid_regex, string), do: :ok, else: :error
  end

  defp extract_framework(%{"metadata" => %{"framework" => framework}}) when is_binary(framework),
    do: framework

  defp extract_framework(_), do: nil

  # Extract env API keys from clientInfo metadata (e.g., OPENROUTER_API_KEY, ANTHROPIC_API_KEY from project env)
  defp extract_env_api_key(client_info) when is_map(client_info) do
    client_info |> get_in(["metadata"]) |> Registry.extract_env_keys()
  end

  defp extract_env_api_key(_), do: %{}

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

  # Streams session history as ACP session/update notifications
  defp stream_session_history(socket, task) do
    task.interactions
    |> Enum.flat_map(&ACPHistory.to_history_items(&1, task.task_id))
    |> Enum.each(fn notification ->
      push(socket, "acp:message", notification)
    end)
  end
end
