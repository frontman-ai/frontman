defmodule SwarmAi.Loop.Config do
  @moduledoc """
  Configuration for loop execution.

  ## Fields

  - `:max_steps` - maximum number of LLM call steps before stopping (default: `20`)
  - `:timeout_ms` - overall loop timeout in milliseconds (default: `300_000` / 5 minutes)
  - `:step_timeout_ms` - per-step timeout in milliseconds (default: `60_000` / 1 minute)
  """
  use TypedStruct

  typedstruct do
    field(:max_steps, non_neg_integer(), default: 20)
    field(:timeout_ms, non_neg_integer(), default: 300_000)
    field(:step_timeout_ms, non_neg_integer(), default: 60_000)
  end
end
