defmodule Swarm.ToolResult do
  @moduledoc """
  Represents the result of a tool execution.

  Used to pass results back to the loop after a tool call has been executed.
  """
  use TypedStruct

  typedstruct enforce: true do
    field :id, String.t()
    field :content, String.t()
    field :is_error, boolean(), default: false
  end
end
