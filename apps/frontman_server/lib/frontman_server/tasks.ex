defmodule FrontmanServer.Tasks do
  @moduledoc """
  Public API for task management.

  Tasks are containers for interactions in a conversation with agents.
  """

  alias FrontmanServer.Tasks.TaskServer
  alias FrontmanServer.Interaction

  @doc """
  Creates a new task and starts its TaskServer.

  The task_id IS the agent_id. Creating a task creates the agent.

  Returns `{:ok, task_id}` on success.
  """
  def create_task(agent_type \\ "mock", config \\ %{}) do
    task_id = Ecto.UUID.generate()

    with {:ok, _pid} <- DynamicSupervisor.start_child(
                          FrontmanServer.TaskSupervisor,
                          {TaskServer, task_id}
                        ),
         {:ok, _interaction} <- add_agent_spawned(task_id, task_id, agent_type, config, nil) do
      {:ok, task_id}
    end
  end

  @doc """
  Checks if a task exists.
  """
  def task_exists?(task_id) do
    case Registry.lookup(FrontmanServer.TaskRegistry, task_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc """
  Appends an interaction to a task's history.
  """
  def append_interaction(task_id, interaction) do
    TaskServer.append_interaction(task_id, interaction)
  end

  @doc """
  Returns all interactions for a task.
  """
  def get_interactions(task_id) do
    TaskServer.get_interactions(task_id)
  end

  @doc """
  Creates and appends a UserMessage interaction.
  """
  def add_user_message(task_id, content, metadata \\ %{}) do
    interaction = %Interaction.UserMessage{
      id: Interaction.new_id(),
      content: content,
      timestamp: Interaction.now(),
      metadata: metadata
    }

    append_interaction(task_id, interaction)
  end

  @doc """
  Creates and appends an AgentResponse interaction.
  """
  def add_agent_response(task_id, agent_id, content, metadata \\ %{}) do
    interaction = %Interaction.AgentResponse{
      id: Interaction.new_id(),
      agent_id: agent_id,
      content: content,
      timestamp: Interaction.now(),
      metadata: metadata
    }

    append_interaction(task_id, interaction)
  end

  @doc """
  Creates and appends an AgentSpawned interaction.
  """
  def add_agent_spawned(task_id, agent_id, agent_type, config \\ %{}, parent_agent_id \\ nil) do
    interaction = %Interaction.AgentSpawned{
      id: Interaction.new_id(),
      agent_id: agent_id,
      agent_type: agent_type,
      config: config,
      parent_agent_id: parent_agent_id,
      timestamp: Interaction.now()
    }

    append_interaction(task_id, interaction)
  end

  @doc """
  Creates and appends an AgentCompleted interaction.
  """
  def add_agent_completed(task_id, agent_id, result \\ nil) do
    interaction = %Interaction.AgentCompleted{
      id: Interaction.new_id(),
      agent_id: agent_id,
      timestamp: Interaction.now(),
      result: result
    }

    append_interaction(task_id, interaction)
  end
end
