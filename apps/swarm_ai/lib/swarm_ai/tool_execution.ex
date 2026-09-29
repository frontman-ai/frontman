defmodule SwarmAi.ToolExecution do
  @moduledoc """
  Describes how a tool call should be executed.

  Applications return these descriptors from the loop's tool preparation callback.
  Swarm runs them through ParallelExecutor, which spawns a task for Sync or
  registers Await in its own receive loop, then collects the results.
  """

  @type t :: SwarmAi.ToolExecution.Sync.t() | SwarmAi.ToolExecution.Await.t()
end
