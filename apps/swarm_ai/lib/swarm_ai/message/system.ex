defmodule SwarmAi.Message.System do
  @moduledoc "System instruction message for a loop conversation."

  use TypedStruct
  alias SwarmAi.Message.ContentPart

  typedstruct do
    field(:content, [ContentPart.t()], default: [])
  end
end
