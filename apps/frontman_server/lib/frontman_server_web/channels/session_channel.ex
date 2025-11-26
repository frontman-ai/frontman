defmodule FrontmanServerWeb.SessionChannel do
  @moduledoc """
  Channel for session-specific ACP events.

  Clients join this channel after creating a session via the
  sessions channel. Handles prompt messages and streams
  agent responses back to the client.
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias FrontmanServer.Tasks
  alias FrontmanServerWeb.{ACP, JsonRpc}

  @impl true
  def join("session:" <> session_id, _params, socket) do
    case Tasks.get_task(session_id) do
      {:ok, _task} ->
        Logger.info("Client joining session: #{session_id}")
        Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "task:#{session_id}")
        socket = assign(socket, :session_id, session_id)
        {:ok, %{session_id: session_id}, socket}

      {:error, :not_found} ->
        Logger.warning("Client tried to join non-existent session: #{session_id}")
        {:error, %{reason: "session_not_found"}}
    end
  end

  @impl true
  def handle_in("acp:message", payload, socket) do
    case JsonRpc.parse(payload) do
      {:ok, {:request, id, "session/prompt", params}} ->
        handle_prompt(id, params, socket)

      {:ok, {:request, id, method, _params}} ->
        Logger.warning("Unknown ACP method in session channel: #{method}")

        response =
          JsonRpc.error_response(
            id,
            JsonRpc.error_method_not_found(),
            "Method not found: #{method}"
          )

        {:reply, {:ok, %{"acp:message" => response}}, socket}

      {:ok, {:notification, _method, _params}} ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  defp handle_prompt(id, params, socket) do
    session_id = socket.assigns.session_id
    prompt_content = Map.get(params, "prompt", [])

    text_content =
      prompt_content
      |> Enum.filter(fn block -> Map.get(block, "type") == "text" end)
      |> Enum.map(fn block -> Map.get(block, "text", "") end)
      |> Enum.join("\n")

    Logger.info("Received prompt for session #{session_id}: #{text_content}")

    socket = assign(socket, :pending_prompt_id, id)

    # Add user message to task - this triggers the real agent
    case Tasks.add_user_message(session_id, text_content) do
      {:ok, _interaction} ->
        Logger.info("User message added, agent spawned for session #{session_id}")

      {:error, reason} ->
        Logger.error("Failed to add user message: #{inspect(reason)}")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stream_token, _agent_id, text}, socket) do
    # Translate domain event to ACP notification
    session_id = socket.assigns.session_id
    notification = ACP.build_agent_message_chunk_notification(session_id, text)
    push(socket, "acp:message", notification)
    {:noreply, socket}
  end

  def handle_info({:agent_completed, _agent_id}, socket) do
    # Translate domain event to ACP response
    case socket.assigns[:pending_prompt_id] do
      nil ->
        {:noreply, socket}

      id ->
        response = JsonRpc.success_response(id, ACP.build_prompt_result("end_turn"))
        push(socket, "acp:message", response)
        socket = assign(socket, :pending_prompt_id, nil)
        {:noreply, socket}
    end
  end

  def handle_info({:interaction, _interaction}, socket) do
    # Interactions are stored, but we stream tokens separately
    {:noreply, socket}
  end

  def handle_info({:agent_error, _agent_id, message}, socket) do
    Logger.error("Agent error: #{message}")

    case socket.assigns[:pending_prompt_id] do
      nil ->
        {:noreply, socket}

      id ->
        response = JsonRpc.error_response(id, -32000, message)
        push(socket, "acp:message", response)
        socket = assign(socket, :pending_prompt_id, nil)
        {:noreply, socket}
    end
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    session_id = socket.assigns[:session_id]
    Logger.info("Client disconnected from session #{session_id}: #{inspect(reason)}")
    :ok
  end
end
