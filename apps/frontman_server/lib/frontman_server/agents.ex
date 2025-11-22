defmodule FrontmanServer.Agents do
  @moduledoc """
  Public API for agent management.

  Agents process user messages and generate responses using LLM.
  Each agent run gets a unique agent_id.
  """

  alias FrontmanServer.Agents.AgentServer

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
  def start_agent(task_id, messages, opts \\ []) do
    require Logger
    agent_id = Ecto.UUID.generate()
    fixture_path = Keyword.get(opts, :fixture_path)

    result =
      DynamicSupervisor.start_child(
        FrontmanServer.AgentSupervisor,
        {AgentServer,
         agent_id: agent_id, task_id: task_id, messages: messages, fixture_path: fixture_path}
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
