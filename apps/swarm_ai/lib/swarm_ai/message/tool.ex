defmodule SwarmAi.Message.Tool do
  use TypedStruct
  alias SwarmAi.Message.ContentPart

  typedstruct do
    field(:content, [ContentPart.t()], default: [])
    field(:tool_call_id, String.t(), enforce: true)
    field(:name, String.t(), enforce: true)
    field(:metadata, map(), default: %{})
  end
end
