defmodule FrontmanServer.Tasks do
  @moduledoc """
  Public API for task management.

  Tasks are containers for interactions in a conversation with agents.
  Each task represents a conversation thread with an AI agent.

  This context provides the boundary for all task-related operations,
  delegating to the domain layer and infrastructure as appropriate.
  """

  alias FrontmanServer.Tasks.{Interaction, Task, TaskStore}
  alias FrontmanServer.Agents

  defdelegate task_exists?(task_id), to: TaskStore, as: :exists?
  defdelegate get_task(task_id), to: TaskStore, as: :get

  @doc """
  Creates a new task and stores it.

  The task_id must be provided by the client.
  Creating a task will automatically spawn an agent to process the initial message.
  Each agent run gets a unique agent_id (separate from task_id).

  Returns `{:ok, task_id}` on success.

  ## Options
  - `:fixture_path` - Path to fixture file for testing (record/replay)
  """
  @spec create_task(%{message: String.t(), task_id: String.t()}, map()) ::
          {:ok, String.t()} | {:error, term()}
  def create_task(%{message: message, task_id: task_id}, config \\ %{}) do
    task = Task.new(task_id, config)
    TaskStore.insert(task)

    fixture_path = Map.get(config, :fixture_path)

    with {:ok, _interaction} <-
           add_user_message(task_id, message, %{}, fixture_path: fixture_path) do
      {:ok, task_id}
    end
  end

  @doc """
  Returns all interactions for a task.
  """
  @spec get_interactions(String.t()) :: list(Interaction.t())
  def get_interactions(task_id) do
    case TaskStore.get(task_id) do
      {:ok, task} -> task.interactions
      {:error, :not_found} -> []
    end
  end

  @spec append_interaction(String.t(), Interaction.t()) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  defp append_interaction(task_id, interaction) do
    case TaskStore.update(task_id, &Task.append_interaction(&1, interaction)) do
      {:ok, _updated_task} ->
        # Broadcast the new interaction to all subscribers
        Phoenix.PubSub.broadcast(
          FrontmanServer.PubSub,
          "task:#{task_id}",
          {:interaction, interaction}
        )

        {:ok, interaction}

      {:error, :not_found} ->
        {:error, :task_not_found}
    end
  end

  @doc """
  Creates and appends a UserMessage interaction.

  Only spawns a new agent if no agent is currently running on this task.
  If an agent is already running, it will pick up the new message in its next iteration.

  ## Options
  - `:fixture_path` - Path to fixture file for testing (record/replay)
  """
  @spec add_user_message(String.t(), String.t(), map(), keyword()) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  def add_user_message(task_id, content, metadata \\ %{}, opts \\ []) do
    interaction = %Interaction.UserMessage{
      id: Interaction.new_id(),
      content: content,
      timestamp: Interaction.now(),
      metadata: metadata
    }

    case append_interaction(task_id, interaction) do
      {:ok, interaction} ->
        # Only spawn a new agent if there isn't one already running
        if Agents.agent_running?(task_id) do
          {:ok, interaction}
        else
          case spawn_and_execute_agent(task_id, %{}, opts) do
            {:ok, _agent_id} -> {:ok, interaction}
            {:error, reason} -> {:error, reason}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates and appends an AgentResponse interaction.
  """
  @spec add_agent_response(String.t(), String.t(), String.t(), map()) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
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
  @spec add_agent_spawned(%{task_id: String.t(), agent_id: String.t()}, map()) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  def add_agent_spawned(%{task_id: task_id, agent_id: agent_id}, config \\ %{}) do
    interaction = %Interaction.AgentSpawned{
      id: Interaction.new_id(),
      agent_id: agent_id,
      config: config,
      timestamp: Interaction.now()
    }

    append_interaction(task_id, interaction)
  end

  @doc """
  Creates and appends an AgentCompleted interaction.
  """
  @spec add_agent_completed(String.t(), String.t(), term()) ::
          {:ok, Interaction.t()} | {:error, :task_not_found}
  def add_agent_completed(task_id, agent_id, result \\ nil) do
    interaction = %Interaction.AgentCompleted{
      id: Interaction.new_id(),
      agent_id: agent_id,
      timestamp: Interaction.now(),
      result: result
    }

    append_interaction(task_id, interaction)
  end

  @spec spawn_and_execute_agent(String.t(), map(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  defp spawn_and_execute_agent(task_id, config, opts) do
    interactions = get_interactions(task_id)
    messages = Interaction.to_llm_messages(interactions)

    case Agents.start_agent(task_id, messages, opts) do
      {:ok, agent_id} ->
        add_agent_spawned(%{task_id: task_id, agent_id: agent_id}, config)
        {:ok, agent_id}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
