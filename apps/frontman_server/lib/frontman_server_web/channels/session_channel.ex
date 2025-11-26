defmodule FrontmanServerWeb.SessionChannel do
  @moduledoc """
  Channel for session-specific ACP events.

  Clients join this channel after creating a session via the
  sessions channel. Handles prompt messages and streams
  agent responses back to the client.
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias FrontmanServer.{ACP, MockAgent, Tasks}

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

  # Handle session/prompt JSON-RPC request
  @impl true
  def handle_in(
        "acp:message",
        %{"jsonrpc" => "2.0", "id" => id, "method" => "session/prompt", "params" => params},
        socket
      ) do
    session_id = socket.assigns.session_id
    prompt_content = Map.get(params, "prompt", [])

    text_content =
      prompt_content
      |> Enum.filter(fn block -> Map.get(block, "type") == "text" end)
      |> Enum.map(fn block -> Map.get(block, "text", "") end)
      |> Enum.join("\n")

    Logger.info("Received prompt for session #{session_id}: #{text_content}")

    # Store the request id so we can respond after streaming completes
    socket = assign(socket, :pending_prompt_id, id)

    # Start mock streaming in background
    spawn(fn -> MockAgent.stream_response(session_id, text_content) end)

    {:noreply, socket}
  end

  # Unknown method handler
  def handle_in("acp:message", %{"jsonrpc" => "2.0", "id" => id, "method" => method}, socket) do
    Logger.warning("Unknown ACP method in session channel: #{method}")

    response = %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => %{
        "code" => ACP.error_method_not_found(),
        "message" => "Method not found: #{method}"
      }
    }

    {:reply, {:ok, %{"acp:message" => response}}, socket}
  end

  # Forward ACP notifications to client
  @impl true
  def handle_info({:acp_notification, notification}, socket) do
    push(socket, "acp:message", notification)
    {:noreply, socket}
  end

  # Handle prompt completion - send final response
  def handle_info({:prompt_complete, stop_reason}, socket) do
    case socket.assigns[:pending_prompt_id] do
      nil ->
        {:noreply, socket}

      id ->
        response = %{
          "jsonrpc" => "2.0",
          "id" => id,
          "result" => ACP.build_prompt_result(stop_reason)
        }

        push(socket, "acp:message", response)
        socket = assign(socket, :pending_prompt_id, nil)
        {:noreply, socket}
    end
  end

  # Catch-all for other PubSub events
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
