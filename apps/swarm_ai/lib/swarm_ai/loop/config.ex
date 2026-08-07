defmodule SwarmAi.Loop.Config do
  use TypedStruct

  typedstruct do
    field(:max_steps, non_neg_integer(), default: 400)
    field(:timeout_ms, non_neg_integer(), default: 300_000)
    field(:step_timeout_ms, non_neg_integer(), default: 60_000)
  end
end
