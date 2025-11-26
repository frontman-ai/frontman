defmodule FrontmanServer.Agents do
  @moduledoc """
  Public API for agent management.

  Agents process user messages and generate responses using LLM.
  Each agent run gets a unique agent_id.
  """

  alias FrontmanServer.Agents.AgentServer
  alias FrontmanServer.Tasks

  @doc """
  Broadcasts a streaming token to task subscribers.
  """
  @spec broadcast_token(atom(), String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def broadcast_token(pubsub, task_id, agent_id, token) do
    Phoenix.PubSub.broadcast(pubsub, Tasks.topic(task_id), {:stream_token, agent_id, token})
  end

  @doc """
  Broadcasts agent completion to task subscribers.
  """
  @spec broadcast_completed(atom(), String.t(), String.t()) :: :ok | {:error, term()}
  def broadcast_completed(pubsub, task_id, agent_id) do
    Phoenix.PubSub.broadcast(pubsub, Tasks.topic(task_id), {:agent_completed, agent_id})
  end

  @doc """
  Broadcasts an agent error to task subscribers.
  """
  @spec broadcast_error(atom(), String.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def broadcast_error(pubsub, task_id, agent_id, message) do
    Phoenix.PubSub.broadcast(pubsub, Tasks.topic(task_id), {:agent_error, agent_id, message})
  end

  @doc """
  Checks if an agent is currently running for the given task.

  Returns `true` if an agent process exists and is alive for this task_id.
  """
  def agent_running?(task_id) do
    case Registry.lookup(FrontmanServer.AgentRegistry, task_id) do
      [{pid, _}] -> Process.alive?(pid)
      [] -> false
    end
  end

  @doc """
  Starts a new agent for the given task and begins execution.

  Creates a unique agent_id (separate from task_id) and spawns AgentServer.
  Each call creates a new agent run - tasks can have multiple agents over their lifetime.
  The agent automatically begins processing after being spawned.

  Returns `{:ok, agent_id}` on success.
  Returns `{:error, {:already_started, pid}}` if an agent is already running for this task.

  ## Options
  - `:fixture_path` - Path to fixture file for testing (record/replay)
  """
  def start_agent(task_id, messages) do
    require Logger
    agent_id = Ecto.UUID.generate()

    result =
      DynamicSupervisor.start_child(
        FrontmanServer.AgentSupervisor,
        {AgentServer, agent_id: agent_id, task_id: task_id, messages: messages}
      )

    case result do
      {:ok, pid} ->
        AgentServer.execute_iteration(pid)
        {:ok, agent_id}

      {:error, reason} ->
        Logger.error("Failed to start agent: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
