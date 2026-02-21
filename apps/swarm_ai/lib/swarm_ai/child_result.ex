defmodule SwarmAi.ChildResult do
  @moduledoc """
  Result from a child agent execution.

  Contains both the result and metadata for observability/replay.
  """
  use TypedStruct

  typedstruct do
    field(:child_loop_id, SwarmAi.Id.t(), enforce: true)
    field(:status, :completed | :failed, enforce: true)
    field(:result, String.t())
    field(:error, term())
    field(:step_count, non_neg_integer(), enforce: true)
    field(:total_tokens, non_neg_integer(), default: 0)
    field(:duration_ms, non_neg_integer(), enforce: true)
    field(:loop, SwarmAi.Loop.t())
  end
end
