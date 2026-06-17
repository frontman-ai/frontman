defmodule SwarmAi.Message.User do
  @moduledoc "User-authored message in a loop conversation."

  use TypedStruct
  alias SwarmAi.Message.ContentPart

  typedstruct do
    field(:content, [ContentPart.t()], default: [])
  end
end
