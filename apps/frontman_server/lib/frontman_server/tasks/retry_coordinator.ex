defmodule FrontmanServer.Tasks.RetryCoordinator do
  @moduledoc """
  Manages server-side retry logic for transient LLM errors.

  Started per-task when a transient error occurs. Sends messages to the
  channel process to drive the retry loop:

  - `{:retrying_status, attempt, max_attempts, retry_at_iso8601, error_message}`
    → channel pushes "retrying" ACP event to client
  - `{:trigger_retry}` → channel re-runs execution for the task
  - `{:retry_exhausted, error_info}` → channel calls handle_turn_error

  The coordinator terminates after handing off in either direction.
  """

  use GenServer

  @max_attempts 5
  @base_delay_ms 2_000
  @max_delay_ms 60_000

  # Public API

  @doc """
  Starts a RetryCoordinator for a task's transient error.

  `channel_pid` is the TaskChannel process.
  `error_info` is `%{message: string, category: string, retryable: bool}`.
  """
  def start(channel_pid, error_info, opts \\ []) do
    GenServer.start(__MODULE__, {channel_pid, error_info, opts})
  end

  @doc """
  Cancels an in-progress retry sequence.
  """
  def cancel(pid) when is_pid(pid) do
    GenServer.cast(pid, :cancel)
  end

  @doc """
  Notifies the coordinator that the retried execution failed again.
  """
  def execution_failed(pid, error_info) do
    send(pid, {:execution_failed, error_info})
  end

  @doc """
  Computes the delay for attempt N with exponential backoff and jitter.
  Public for testability.
  """
  def compute_delay(attempt, base_delay_ms, max_delay_ms) do
    base = trunc(base_delay_ms * :math.pow(2, attempt - 1))
    jitter = :rand.uniform(max(1, div(base, 4)))
    min(base + jitter, max_delay_ms)
  end

  # GenServer callbacks

  @impl true
  def init({channel_pid, error_info, opts}) do
    max_attempts = Keyword.get(opts, :max_attempts, @max_attempts)
    base_delay_ms = Keyword.get(opts, :base_delay_ms, @base_delay_ms)
    max_delay_ms = Keyword.get(opts, :max_delay_ms, @max_delay_ms)

    state = %{
      channel_pid: channel_pid,
      error_info: error_info,
      attempt: 1,
      max_attempts: max_attempts,
      base_delay_ms: base_delay_ms,
      max_delay_ms: max_delay_ms
    }

    {:ok, state, {:continue, :start}}
  end

  @impl true
  def handle_continue(:start, %{error_info: %{retryable: false}} = state) do
    send(state.channel_pid, {:retry_exhausted, state.error_info})
    {:stop, :normal, state}
  end

  def handle_continue(:start, state) do
    schedule_retry(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:fire_retry, state) do
    send(state.channel_pid, {:trigger_retry})
    {:noreply, state}
  end

  def handle_info({:execution_failed, error_info}, state) do
    next_attempt = state.attempt + 1

    if next_attempt > state.max_attempts do
      send(state.channel_pid, {:retry_exhausted, error_info})
      {:stop, :normal, state}
    else
      new_state = %{state | attempt: next_attempt, error_info: error_info}
      schedule_retry(new_state)
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_cast(:cancel, state) do
    send(state.channel_pid, {:retry_exhausted, %{kind: "cancelled"}})
    {:stop, :normal, state}
  end

  # Schedules the next retry: pushes retrying_status to channel, then fires trigger after delay.
  defp schedule_retry(state) do
    delay = compute_delay(state.attempt, state.base_delay_ms, state.max_delay_ms)
    retry_at = DateTime.utc_now() |> DateTime.add(delay, :millisecond) |> DateTime.to_iso8601()

    send(state.channel_pid, {
      :retrying_status,
      state.attempt,
      state.max_attempts,
      retry_at,
      state.error_info.message
    })

    Process.send_after(self(), :fire_retry, delay)
  end
end
