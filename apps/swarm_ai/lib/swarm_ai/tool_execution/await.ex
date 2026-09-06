defmodule SwarmAi.ToolExecution.Await do
  @moduledoc """
  A tool that awaits an external message (e.g. a browser client response).

  PE calls the start MFA in its own process:

      apply(mod, fun, args ++ [tool_call]) :: :ok

  Then waits for `{:tool_result, tool_call_id, content, is_error}` in its
  receive loop. No separate task is spawned — PE's receive loop IS the
  waiting mechanism. `timeout_ms: :infinity` creates no timer. This is the
  explicit exception to bounded execution for interactive human input; the
  parked executor retains its history in memory and remains cancellable.

  For a finite deadline, PE calls the `on_error` MFA with appended arguments
  `[:timeout, tool_call]`. The callback must return the canonical `ToolResult.t()`.
  """

  use TypedStruct

  alias SwarmAi.ToolCall

  typedstruct enforce: true do
    field(:tool_call, ToolCall.t())
    field(:timeout_ms, pos_integer() | :infinity)

    field(:start, {module(), atom(), list()})

    field(:on_error, {module(), atom(), list()})
  end
end
