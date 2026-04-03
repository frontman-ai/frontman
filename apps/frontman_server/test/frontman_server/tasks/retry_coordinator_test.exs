defmodule FrontmanServer.Tasks.RetryCoordinatorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.RetryCoordinator

  @retryable_error %{message: "Rate limited", category: "rate_limit", retryable: true}
  @non_retryable_error %{message: "Auth failed", category: "auth", retryable: false}

  describe "handle_error/3 with nil state (first error)" do
    test "non-retryable error returns exhausted immediately" do
      assert {:exhausted, @non_retryable_error} =
               RetryCoordinator.handle_error(nil, @non_retryable_error)
    end

    test "retryable error returns retry_scheduled with state and notification data" do
      {:retry_scheduled, state, notification} =
        RetryCoordinator.handle_error(nil, @retryable_error, base_delay_ms: 50)

      assert %RetryCoordinator{attempt: 1, max_attempts: 5} = state
      assert is_reference(state.timer_ref)
      assert notification.attempt == 1
      assert notification.max_attempts == 5
      assert notification.message == "Rate limited"
      assert notification.category == "rate_limit"
      assert %DateTime{} = notification.retry_at

      # Timer fires in the calling process
      assert_receive :fire_retry, 500

      # Clean up
      RetryCoordinator.clear(state)
    end

    test "respects custom max_attempts option" do
      {:retry_scheduled, state, notification} =
        RetryCoordinator.handle_error(nil, @retryable_error,
          base_delay_ms: 50,
          max_attempts: 2
        )

      assert state.max_attempts == 2
      assert notification.max_attempts == 2
      RetryCoordinator.clear(state)
    end
  end

  describe "handle_error/3 with existing state (subsequent error)" do
    test "increments attempt and schedules retry" do
      {:retry_scheduled, state1, _} =
        RetryCoordinator.handle_error(nil, @retryable_error, base_delay_ms: 50)

      assert_receive :fire_retry, 500

      {:retry_scheduled, state2, notification} =
        RetryCoordinator.handle_error(state1, @retryable_error)

      assert state2.attempt == 2
      assert notification.attempt == 2
      assert_receive :fire_retry, 500
      RetryCoordinator.clear(state2)
    end

    test "returns exhausted when max_attempts exceeded" do
      {:retry_scheduled, state1, _} =
        RetryCoordinator.handle_error(nil, @retryable_error,
          base_delay_ms: 50,
          max_attempts: 1
        )

      assert_receive :fire_retry, 500

      assert {:exhausted, @retryable_error} =
               RetryCoordinator.handle_error(state1, @retryable_error)
    end

    test "cancels previous timer before scheduling new one" do
      {:retry_scheduled, state1, _} =
        RetryCoordinator.handle_error(nil, @retryable_error, base_delay_ms: 5_000)

      old_ref = state1.timer_ref

      {:retry_scheduled, state2, _} =
        RetryCoordinator.handle_error(state1, @retryable_error)

      # Old timer was cancelled
      assert Process.cancel_timer(old_ref) == false
      # New timer is active
      assert is_integer(Process.cancel_timer(state2.timer_ref))
      RetryCoordinator.clear(state2)
    end
  end

  describe "clear/1" do
    test "returns nil for nil state" do
      assert RetryCoordinator.clear(nil) == nil
    end

    test "cancels timer and returns nil" do
      {:retry_scheduled, state, _} =
        RetryCoordinator.handle_error(nil, @retryable_error, base_delay_ms: 5_000)

      assert is_reference(state.timer_ref)
      assert RetryCoordinator.clear(state) == nil

      # Timer should no longer fire
      refute_receive :fire_retry, 100
    end
  end

  describe "compute_delay/3" do
    test "grows exponentially with jitter" do
      delay1 = RetryCoordinator.compute_delay(1, 1000, 60_000)
      delay2 = RetryCoordinator.compute_delay(2, 1000, 60_000)
      delay3 = RetryCoordinator.compute_delay(3, 1000, 60_000)

      assert delay1 >= 1000 and delay1 <= 1250
      assert delay2 >= 2000 and delay2 <= 2500
      assert delay3 >= 4000 and delay3 <= 5000
    end

    test "caps at max_delay_ms" do
      delay = RetryCoordinator.compute_delay(10, 1000, 5000)
      assert delay <= 5000
    end
  end
end
