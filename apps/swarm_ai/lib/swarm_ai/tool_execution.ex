defmodule SwarmAi.ToolExecution do
  @type t :: SwarmAi.ToolExecution.Sync.t() | SwarmAi.ToolExecution.Await.t()
end
