defmodule SwarmAi.LLM.Usage do
  @moduledoc """
  Token usage from an LLM call.

  Canonical type used by Response and Step.
  """
  use TypedStruct

  typedstruct do
    field(:input_tokens, non_neg_integer(), enforce: true)
    field(:output_tokens, non_neg_integer(), enforce: true)
    field(:reasoning_tokens, non_neg_integer(), default: 0)
    field(:cached_tokens, non_neg_integer(), default: 0)
  end

  @doc """
  Builds a `Usage` struct from a map with atom keys and integer defaults.

  Useful for constructing usage from telemetry metadata or streaming chunks
  where fields may be absent.

  ## Examples

      iex> Usage.from_map(%{input_tokens: 100, output_tokens: 50})
      %Usage{input_tokens: 100, output_tokens: 50, reasoning_tokens: 0, cached_tokens: 0}
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      input_tokens: Map.get(map, :input_tokens, 0),
      output_tokens: Map.get(map, :output_tokens, 0),
      reasoning_tokens: Map.get(map, :reasoning_tokens, 0),
      cached_tokens: Map.get(map, :cached_tokens, 0)
    }
  end

  @doc """
  Returns the total token count (input + output + reasoning).

  Cached tokens are a subset of input tokens and not added separately.
  """
  @spec total_tokens(t()) :: non_neg_integer()
  def total_tokens(%__MODULE__{
        input_tokens: input,
        output_tokens: output,
        reasoning_tokens: reasoning
      }) do
    input + output + reasoning
  end
end
