defmodule Swarm.LLM.Response do
  use TypedStruct

  typedstruct do
    field :content, String.t()
    field :usage, %{input_tokens: non_neg_integer(), output_tokens: non_neg_integer()}
    field :raw, term()
  end
end
