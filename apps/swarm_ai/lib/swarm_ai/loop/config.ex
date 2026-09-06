defmodule SwarmAi.Loop.Config do
  @moduledoc """
  Configuration for loop execution.

  ## Fields

  - `:max_steps` - maximum number of LLM call steps before stopping (default: `400`)
  - `:step_timeout_ms` - per-step timeout in milliseconds (default: `60_000` / 1 minute)
  """
  use TypedStruct

  typedstruct do
    field(:max_steps, non_neg_integer(), default: 400)
    field(:step_timeout_ms, non_neg_integer(), default: 60_000)
  end
end
