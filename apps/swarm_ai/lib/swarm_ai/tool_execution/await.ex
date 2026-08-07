defmodule SwarmAi.ToolExecution.Await do
  use TypedStruct

  alias SwarmAi.ToolCall

  typedstruct enforce: true do
    field(:tool_call, ToolCall.t())
    field(:timeout_ms, pos_integer())
    field(:on_timeout_policy, :error | :pause_agent)

    field(:start, {module(), atom(), list()})

    field(:on_timeout, {module(), atom(), list()})
  end
end
