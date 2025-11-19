defmodule FrontmanServer.Agents do
  @moduledoc """
  Public API for agent management.

  Agents process user messages and generate responses.
  The root agent_id equals the task_id.
  """

  alias FrontmanServer.Agents.MockAgentServer

  @doc """
  Starts the agent for a task.

  The agent_id equals the task_id.

  Returns `{:ok, agent_id}` on success.
  """
  def start_agent(task_id) do
    # Start the agent server (agent_id === task_id)
    case DynamicSupervisor.start_child(
           FrontmanServer.AgentSupervisor,
           {MockAgentServer, agent_id: task_id, task_id: task_id}
         ) do
      {:ok, _pid} -> {:ok, task_id}
      {:error, reason} -> {:error, reason}
    end
  end
end
