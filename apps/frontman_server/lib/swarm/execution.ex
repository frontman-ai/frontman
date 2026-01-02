defmodule Swarm.Execution do
  @moduledoc """
  Handle returned from Swarm.start/3 for tracking async executions.

  Contains the execution ID and process PID, allowing callers to:
  - Receive events via `{:swarm, execution.id, event}` messages
  - Block for completion via `Swarm.await/1`
  """
  use TypedStruct

  typedstruct do
    field :id, Swarm.Id.t(), enforce: true
    field :pid, pid(), enforce: true
  end
end
