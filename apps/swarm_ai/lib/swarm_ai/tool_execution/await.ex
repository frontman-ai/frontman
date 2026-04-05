defmodule SwarmAi.ToolExecution.Await do
  @moduledoc """
  A tool that awaits an external message (e.g. a browser client response).

  PE calls the start MFA in its own process:

      apply(mod, fun, args ++ [tool_call]) :: :ok

  Then waits for `{:tool_result, message_key, content, is_error}` in its
  receive loop. No separate task is spawned — PE's receive loop IS the
  waiting mechanism.
  """

  use TypedStruct

  alias SwarmAi.ToolCall

  typedstruct enforce: true do
    field :tool_call, ToolCall.t()
    field :timeout_ms, pos_integer()
    field :on_timeout_policy, :error | :pause_agent

    # apply(mod, fun, args ++ [tool_call]) :: :ok  (called in PE's own process)
    field :start, {module(), atom(), list()}

    # PE matches {:tool_result, message_key, content, is_error} in its receive loop
    field :message_key, term()

    # apply(mod, fun, args ++ [tool_call, :triggered | :cancelled]) :: :ok
    field :on_timeout, {module(), atom(), list()}
  end
end
