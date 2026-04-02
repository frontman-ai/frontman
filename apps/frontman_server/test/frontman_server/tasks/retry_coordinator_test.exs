defmodule FrontmanServer.Tasks.RetryCoordinatorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.RetryCoordinator

  # short delays for tests
  @base_delay_ms 50

  defp start_coordinator(channel_pid, error_info, opts \\ []) do
    opts = Keyword.merge([base_delay_ms: @base_delay_ms, max_delay_ms: 500], opts)
    {:ok, pid} = RetryCoordinator.start(channel_pid, error_info, opts)
    pid
  end

  describe "retry scheduling" do
    test "sends retrying_status then trigger_retry for retryable error" do
      error = %{message: "Rate limited", category: "rate_limit", retryable: true}
      pid = start_coordinator(self(), error)

      assert_receive {:retrying_status, 1, 5, _retry_at, "Rate limited", "rate_limit"}, 500
      assert_receive {:trigger_retry}, 500

      # Clean up
      GenServer.stop(pid, :normal)
    end

    test "sends up to max_attempts retrying_status messages before exhausting" do
      error = %{message: "Overloaded", category: "overload", retryable: true}
      pid = start_coordinator(self(), error, max_attempts: 2)

      assert_receive {:retrying_status, 1, 2, _, _, _}, 500
      assert_receive {:trigger_retry}, 500

      # Simulate execution failed again
      send(pid, {:execution_failed, error})

      assert_receive {:retrying_status, 2, 2, _, _, _}, 500
      assert_receive {:trigger_retry}, 500

      # One more failure exhausts it
      send(pid, {:execution_failed, error})
      assert_receive {:retry_exhausted, ^error}, 500
      # Give the process time to fully terminate
      Process.sleep(10)
      refute Process.alive?(pid)
    end

    test "does not retry non-retryable error" do
      error = %{message: "Auth failed", category: "auth", retryable: false}
      pid = start_coordinator(self(), error)

      assert_receive {:retry_exhausted, ^error}, 500
      # Give the process time to fully terminate
      Process.sleep(10)
      refute Process.alive?(pid)
    end
  end

  describe "cancel" do
    test "stops the coordinator and sends retry_exhausted with cancelled error" do
      error = %{message: "Overloaded", category: "overload", retryable: true}
      pid = start_coordinator(self(), error)

      assert_receive {:retrying_status, 1, 5, _, _, _}, 500
      # Cancel before trigger_retry fires
      RetryCoordinator.cancel(pid)

      assert_receive {:retry_exhausted, %{kind: "cancelled"}}, 500
      # Give the process time to fully terminate
      Process.sleep(10)
      refute Process.alive?(pid)
    end
  end

  describe "bug: category missing from retrying_status tuple" do
    test "retrying_status message includes the error category" do
      # BUG: schedule_retry/1 builds the :retrying_status tuple with only
      # {attempt, max_attempts, retry_at, message} — category is omitted.
      # The channel's handle_info handler has no category to forward to
      # ACP.build_error_notification, so retrying notifications always show "unknown".
      error = %{message: "Rate limited", category: "rate_limit", retryable: true}
      pid = start_coordinator(self(), error)

      assert_receive {:retrying_status, 1, 5, _retry_at, "Rate limited", "rate_limit"}, 500

      GenServer.stop(pid, :normal)
    end
  end

  describe "bug: coordinator stays alive after trigger_retry, enabling stale reuse" do
    test "execution_failed after trigger_retry uses stale attempt counter" do
      # Documents the mechanism behind the channel-level stale-coordinator bug.
      # After trigger_retry fires, the coordinator stays alive.
      # If handle_turn_ended does NOT stop it and a new execution fails,
      # the channel sends execution_failed to the stale coordinator, which
      # reports attempt 2 (stale) instead of a fresh attempt 1.
      error = %{message: "Rate limited", category: "rate_limit", retryable: true}
      pid = start_coordinator(self(), error, max_attempts: 3)

      assert_receive {:retrying_status, 1, 3, _, _, _}, 500
      assert_receive {:trigger_retry}, 500

      assert Process.alive?(pid)

      # Stale execution_failed (from a new, different execution)
      send(pid, {:execution_failed, error})

      # Documents: reports attempt 2 — handle_turn_ended must stop this coordinator
      # on agent_completed so handle_transient_error creates a fresh one at attempt 1
      assert_receive {:retrying_status, 2, 3, _, _, _}, 500

      GenServer.stop(pid, :normal)
    end
  end

  describe "backoff math" do
    test "compute_delay grows exponentially with jitter" do
      delay1 = RetryCoordinator.compute_delay(1, 1000, 60_000)
      delay2 = RetryCoordinator.compute_delay(2, 1000, 60_000)
      delay3 = RetryCoordinator.compute_delay(3, 1000, 60_000)

      # Each delay should be larger (base doubles), with jitter up to 25%
      assert delay1 >= 1000 and delay1 <= 1250
      assert delay2 >= 2000 and delay2 <= 2500
      assert delay3 >= 4000 and delay3 <= 5000
    end

    test "compute_delay caps at max_delay_ms" do
      delay = RetryCoordinator.compute_delay(10, 1000, 5000)
      assert delay <= 5000
    end
  end
end
