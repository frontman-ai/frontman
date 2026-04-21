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
      input_tokens:
        usage_value(map, [:input_tokens, "input_tokens", :prompt_tokens, "prompt_tokens"]),
      output_tokens:
        usage_value(map, [
          :output_tokens,
          "output_tokens",
          :completion_tokens,
          "completion_tokens"
        ]),
      reasoning_tokens:
        usage_value(map, [:reasoning_tokens, "reasoning_tokens", :reasoning, "reasoning"]),
      cached_tokens:
        usage_value(map, [:cached_tokens, "cached_tokens", :cached_input, "cached_input"])
    }
  end

  defp usage_value(map, keys) do
    keys
    |> Enum.find_value(&Map.get(map, &1))
    |> normalize_usage_value()
  end

  defp normalize_usage_value(value) when is_integer(value) and value >= 0, do: value
  defp normalize_usage_value(_value), do: 0

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
