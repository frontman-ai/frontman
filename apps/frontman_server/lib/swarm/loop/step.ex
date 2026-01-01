defmodule Swarm.Loop.Step do
  @moduledoc """
  Represents a single step in the agentic loop.

  Each step tracks one LLM iteration:
  - `input_messages` - Messages sent TO the LLM (system, user, assistant messages)
  - `content` - Text response received FROM the LLM
  - `usage` - Token usage stats: %{input_tokens: int, output_tokens: int}
  - `started_at` - When the LLM call was initiated
  - `completed_at` - When the LLM response was received
  - `duration_ms` - How long the LLM call took

  Steps are created when an iteration starts and completed when the LLM responds.
  """

  use TypedStruct

  @type usage :: %{
          input_tokens: non_neg_integer(),
          output_tokens: non_neg_integer()
        }

  typedstruct do
    field :number, pos_integer(), enforce: true
    field :input_messages, [map()], default: []
    field :content, String.t()
    field :usage, usage()
    field :started_at, DateTime.t(), enforce: true
    field :completed_at, DateTime.t()
    field :duration_ms, non_neg_integer()
  end

  @doc """
  Creates a new step for an LLM iteration.

  ## Example

      step = Step.new(1, [
        %{role: "system", content: "You are helpful"},
        %{role: "user", content: "Hello"}
      ])
  """
  @spec new(pos_integer(), [map()]) :: t()
  def new(number, input_messages) do
    %__MODULE__{
      number: number,
      input_messages: input_messages,
      started_at: DateTime.utc_now()
    }
  end
end
