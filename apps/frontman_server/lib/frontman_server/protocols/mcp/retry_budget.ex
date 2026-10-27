defmodule FrontmanServer.Protocols.MCP.RetryBudget do
  @moduledoc """
  Caller-configured finite limits for one logical operation, including its initial attempt.
  No defaults or dispatch permission. The executor must enforce the same total deadline
  while executing or waiting; checking only between attempts cannot bound a blocked call.
  Elapsed milliseconds must come from a monotonic clock anchored at operation start.
  """
  @enforce_keys [:attempts_max, :elapsed_ms_max]
  defstruct [:attempts_max, :elapsed_ms_max, attempts: 1, elapsed_ms: 0]

  @opaque t :: %__MODULE__{
            attempts_max: pos_integer(),
            elapsed_ms_max: pos_integer(),
            attempts: pos_integer(),
            elapsed_ms: non_neg_integer()
          }

  @spec new(term(), term()) :: {:ok, t()} | {:error, :invalid_budget}
  def new(attempts_max, elapsed_ms_max)
      when is_integer(attempts_max) and attempts_max > 0 and
             is_integer(elapsed_ms_max) and elapsed_ms_max > 0,
      do: {:ok, %__MODULE__{attempts_max: attempts_max, elapsed_ms_max: elapsed_ms_max}}

  def new(_attempts_max, _elapsed_ms_max), do: {:error, :invalid_budget}

  @spec advance(t(), term()) ::
          {:ok, t()} | {:error, :invalid_elapsed | :retry_exhausted}
  def advance(%__MODULE__{} = budget, elapsed_ms)
      when is_integer(elapsed_ms) and elapsed_ms >= budget.elapsed_ms do
    cond do
      budget.attempts >= budget.attempts_max -> {:error, :retry_exhausted}
      elapsed_ms >= budget.elapsed_ms_max -> {:error, :retry_exhausted}
      true -> {:ok, %{budget | attempts: budget.attempts + 1, elapsed_ms: elapsed_ms}}
    end
  end

  def advance(%__MODULE__{}, _elapsed_ms), do: {:error, :invalid_elapsed}
end
