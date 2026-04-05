defmodule SwarmAi.ToolExecution do
  @moduledoc """
  Describes how a tool call should be executed.

  Executors return a list of these structs — PE pattern-matches on the struct
  type to decide whether to spawn a task (Sync) or register in its own receive
  loop (Await). This makes the executor contract explicit and gives PE full
  ownership of execution lifecycle.
  """

  @type t :: SwarmAi.ToolExecution.Sync.t() | SwarmAi.ToolExecution.Await.t()
end
