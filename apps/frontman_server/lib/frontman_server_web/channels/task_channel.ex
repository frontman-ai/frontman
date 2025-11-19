defmodule FrontmanServerWeb.TaskChannel do
  @moduledoc """
  WebSocket channel for task communication.

  Handles task creation, message sending, and streaming events.
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias FrontmanServer.{Tasks, Agents}

  @impl true
  def join("task:new", _params, socket) do
    case Tasks.create_task() do
      {:ok, task_id} ->
        Logger.info("Created new task/agent: #{task_id}")

        # Subscribe to task events
        Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "task:#{task_id}")

        # Get interactions (should have AgentSpawned)
        interactions = Tasks.get_interactions(task_id)

        socket = assign(socket, :task_id, task_id)
        {:ok, %{task_id: task_id, interactions: serialize_interactions(interactions)}, socket}

      {:error, reason} ->
        {:error, %{reason: inspect(reason)}}
    end
  end

  @impl true
  def join("task:" <> task_id, _params, socket) do
    if Tasks.task_exists?(task_id) do
      Logger.info("Resuming task: #{task_id}")

      # Subscribe to task events
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "task:#{task_id}")

      # Get existing interactions
      interactions = Tasks.get_interactions(task_id)

      socket = assign(socket, :task_id, task_id)
      {:ok, %{task_id: task_id, interactions: serialize_interactions(interactions)}, socket}
    else
      {:error, %{reason: "task_not_found"}}
    end
  end

  @impl true
  def handle_in("send_message", %{"content" => content}, socket) do
    task_id = socket.assigns.task_id

    # Add user message interaction
    {:ok, _interaction} = Tasks.add_user_message(task_id, content)

    # Start agent to respond (agent_id === task_id)
    {:ok, _agent_id} = Agents.start_agent(task_id)

    {:reply, :ok, socket}
  end


  # PubSub event handlers

  @impl true
  def handle_info({:interaction, interaction}, socket) do
    # Broadcast domain interaction to client
    push(socket, "interaction", serialize_interaction(interaction))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:stream_token, agent_id, token}, socket) do
    # Broadcast ephemeral stream token to client
    push(socket, "stream_token", %{agent_id: agent_id, token: token})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:agent_completed, agent_id}, socket) do
    # Broadcast agent completion to client
    push(socket, "agent_completed", %{agent_id: agent_id})
    {:noreply, socket}
  end

  # Private functions

  defp serialize_interactions(interactions) do
    Enum.map(interactions, &serialize_interaction/1)
  end

  defp serialize_interaction(%FrontmanServer.Interaction.UserMessage{} = interaction) do
    %{
      type: "user_message",
      id: interaction.id,
      content: interaction.content,
      timestamp: DateTime.to_iso8601(interaction.timestamp),
      metadata: interaction.metadata
    }
  end

  defp serialize_interaction(%FrontmanServer.Interaction.AgentResponse{} = interaction) do
    %{
      type: "agent_response",
      id: interaction.id,
      agent_id: interaction.agent_id,
      content: interaction.content,
      timestamp: DateTime.to_iso8601(interaction.timestamp),
      metadata: interaction.metadata
    }
  end

  defp serialize_interaction(%FrontmanServer.Interaction.AgentSpawned{} = interaction) do
    %{
      type: "agent_spawned",
      id: interaction.id,
      agent_id: interaction.agent_id,
      agent_type: interaction.agent_type,
      config: interaction.config,
      parent_agent_id: interaction.parent_agent_id,
      timestamp: DateTime.to_iso8601(interaction.timestamp)
    }
  end

  defp serialize_interaction(%FrontmanServer.Interaction.AgentCompleted{} = interaction) do
    %{
      type: "agent_completed",
      id: interaction.id,
      agent_id: interaction.agent_id,
      timestamp: DateTime.to_iso8601(interaction.timestamp),
      result: interaction.result
    }
  end
end
