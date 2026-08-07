defmodule SwarmAi.Message.Assistant do
  @moduledoc """
  Assistant message with text content, tool calls, and provider metadata.
  """

  use TypedStruct
  alias SwarmAi.Message.ContentPart

  typedstruct do
    field(:content, [ContentPart.t()], default: [])
    field(:tool_calls, [SwarmAi.ToolCall.t()], default: [])
    field(:metadata, map(), default: %{})
    field(:reasoning_details, [map()] | nil, default: nil)
  end
end
