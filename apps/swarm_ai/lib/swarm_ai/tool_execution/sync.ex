defmodule SwarmAi.ToolExecution.Sync do
  @moduledoc """
  A tool that executes synchronously in a spawned Task.

  PE spawns a supervised task and calls:

      apply(mod, fun, args ++ [tool_call]) :: ToolResult.t()

  PE kills and awaits termination of the task on deadline, then calls the
  `on_error` MFA with appended arguments `[:timeout, tool_call]`.
  A task crash calls the same MFA with `[{:crashed, exit_reason}, tool_call]`.
  The callback must return the canonical `ToolResult.t()`, including any
  persistence race winner.
  """

  use TypedStruct

  alias SwarmAi.ToolCall

  typedstruct enforce: true do
    field(:tool_call, ToolCall.t())
    field(:timeout_ms, pos_integer())

    field(:run, {module(), atom(), list()})

    field(:on_error, {module(), atom(), list()})
  end
end
