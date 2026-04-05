defmodule SwarmAi.ToolExecution.Sync do
  @moduledoc """
  A tool that executes synchronously in a spawned Task.

  PE spawns a supervised task and calls:

      apply(mod, fun, args ++ [tool_call]) :: ToolResult.t()

  The task may block as long as needed. PE kills it on deadline.
  """

  use TypedStruct

  alias SwarmAi.ToolCall

  typedstruct enforce: true do
    field :tool_call, ToolCall.t()
    field :timeout_ms, pos_integer()
    field :on_timeout_policy, :error | :pause_agent

    # apply(mod, fun, args ++ [tool_call]) :: ToolResult.t()
    field :run, {module(), atom(), list()}

    # apply(mod, fun, args ++ [tool_call, :triggered | :cancelled]) :: :ok
    field :on_timeout, {module(), atom(), list()}
  end
end
