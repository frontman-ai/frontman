defmodule SwarmAi.ToolExecution do
  @moduledoc """
  Describes how a tool call should be executed.

  Executors return a list of these structs — PE pattern-matches on the struct
  type to decide whether to spawn a task (Sync) or register in its own receive
  loop (Await). PE runs the descriptors and collects their results.
  """

  @type t :: SwarmAi.ToolExecution.Sync.t() | SwarmAi.ToolExecution.Await.t()
end
