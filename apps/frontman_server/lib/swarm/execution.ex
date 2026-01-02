defmodule Swarm.Execution do
  @moduledoc """
  Handle returned from Swarm.start/3 for tracking async executions.

  Contains the execution ID, process PID, and agent, allowing callers to:
  - Receive events via `{:swarm, execution.id, event}` messages
  - Block for completion via `Swarm.await/1`
  - Access agent metadata (e.g., `execution.agent.node_id`)
  """
  use TypedStruct

  typedstruct do
    field :id, Swarm.Id.t(), enforce: true
    field :pid, pid(), enforce: true
    field :agent, Swarm.Agent.t(), enforce: true
  end
end
