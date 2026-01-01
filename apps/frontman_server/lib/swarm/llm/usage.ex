defmodule Swarm.LLM.Usage do
  @moduledoc """
  Token usage from an LLM call.

  Canonical type used by Response and Step.
  """
  use TypedStruct

  typedstruct do
    field :input_tokens, non_neg_integer(), enforce: true
    field :output_tokens, non_neg_integer(), enforce: true
  end
end
