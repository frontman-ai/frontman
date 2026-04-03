defmodule FrontmanServer.Tasks.RetryCoordinator do
  @moduledoc """
  Manages retry state for transient LLM errors.

  A plain module — state is stored as a struct in socket assigns,
  timers are owned by the calling process (the channel).
  """

  @enforce_keys [:attempt, :max_attempts, :error_info, :timer_ref, :base_delay_ms, :max_delay_ms]
  defstruct [:attempt, :max_attempts, :error_info, :timer_ref, :base_delay_ms, :max_delay_ms]

  @type t :: %__MODULE__{
          attempt: pos_integer(),
          max_attempts: pos_integer(),
          error_info: map(),
          timer_ref: reference() | nil,
          base_delay_ms: pos_integer(),
          max_delay_ms: pos_integer()
        }

  @default_max_attempts 5
  @default_base_delay_ms 2_000
  @default_max_delay_ms 60_000

  @doc """
  Handles a transient error. Creates or advances retry state.

  Returns `{:retry_scheduled, state, notification_data}` or `{:exhausted, error_info}`.
  Schedules a `:fire_retry` message in the calling process when retrying.
  """
  @spec handle_error(t() | nil, map(), keyword()) ::
          {:retry_scheduled, t(), map()} | {:exhausted, map()}
  def handle_error(state, error_info, opts \\ [])

  def handle_error(nil, %{retryable: false} = error_info, _opts) do
    {:exhausted, error_info}
  end

  def handle_error(nil, error_info, opts) do
    max_attempts = Keyword.get(opts, :max_attempts, @default_max_attempts)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @default_base_delay_ms)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, @default_max_delay_ms)

    state = %__MODULE__{
      attempt: 1,
      max_attempts: max_attempts,
      error_info: error_info,
      timer_ref: nil,
      base_delay_ms: base_delay_ms,
      max_delay_ms: max_delay_ms
    }

    schedule_retry(state)
  end

  def handle_error(%__MODULE__{} = state, error_info, _opts) do
    next_attempt = state.attempt + 1

    if next_attempt > state.max_attempts do
      cancel_timer(state.timer_ref)
      {:exhausted, error_info}
    else
      state = %{state | attempt: next_attempt, error_info: error_info}
      schedule_retry(state)
    end
  end

  @doc """
  Clears retry state. Cancels any pending timer. Returns nil.
  """
  @spec clear(t() | nil) :: nil
  def clear(nil), do: nil

  def clear(%__MODULE__{timer_ref: ref}) do
    cancel_timer(ref)
    nil
  end

  @doc """
  Computes the delay for attempt N with exponential backoff and jitter.
  """
  @spec compute_delay(pos_integer(), pos_integer(), pos_integer()) :: pos_integer()
  def compute_delay(attempt, base_delay_ms, max_delay_ms) do
    base = trunc(base_delay_ms * :math.pow(2, attempt - 1))
    jitter = :rand.uniform(max(1, div(base, 4)))
    min(base + jitter, max_delay_ms)
  end

  defp schedule_retry(state) do
    cancel_timer(state.timer_ref)
    delay = compute_delay(state.attempt, state.base_delay_ms, state.max_delay_ms)
    retry_at = DateTime.utc_now() |> DateTime.add(delay, :millisecond)
    ref = Process.send_after(self(), :fire_retry, delay)
    state = %{state | timer_ref: ref}

    notification = %{
      attempt: state.attempt,
      max_attempts: state.max_attempts,
      retry_at: retry_at,
      message: state.error_info.message,
      category: state.error_info.category
    }

    {:retry_scheduled, state, notification}
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(ref), do: Process.cancel_timer(ref) && :ok
end
