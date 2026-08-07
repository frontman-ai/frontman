defmodule SwarmAi.Message.System do
  use TypedStruct
  alias SwarmAi.Message.ContentPart

  typedstruct do
    field(:content, [ContentPart.t()], default: [])
  end
end
