defmodule FrontmanServer.Tasks.StreamCleanupTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.StreamCleanup

  describe "wrap_stream/2" do
    test "calls cancel_fn when stream is fully consumed" do
      test_pid = self()
      cancel_fn = fn -> send(test_pid, :cancel_called) end

      stream =
        [1, 2, 3]
        |> StreamCleanup.wrap_stream(cancel_fn)

      result = Enum.to_list(stream)

      assert result == [1, 2, 3]
      # after_fn always calls cancel (idempotent) to release the connection.
      assert_receive :cancel_called, 500
    end

    test "calls cancel_fn when consumer process is killed" do
      test_pid = self()
      cancel_fn = fn -> send(test_pid, :cancel_called) end

      consumer =
        spawn(fn ->
          # Slow stream that will be interrupted
          Stream.repeatedly(fn ->
            Process.sleep(100)
            :tick
          end)
          |> StreamCleanup.wrap_stream(cancel_fn)
          |> Enum.take(100)
        end)

      # Let the stream start consuming
      Process.sleep(50)

      # Kill the consumer (simulates Runtime.cancel)
      Process.exit(consumer, :cancelled)

      # The linked cleanup process should catch the EXIT and call cancel_fn
      assert_receive :cancel_called, 1_000
    end

    test "calls cancel_fn when stream raises" do
      test_pid = self()
      cancel_fn = fn -> send(test_pid, :cancel_called) end

      error_stream =
        Stream.resource(
          fn -> 0 end,
          fn
            2 -> raise "boom"
            n -> {[n], n + 1}
          end,
          fn _ -> :ok end
        )

      wrapped = StreamCleanup.wrap_stream(error_stream, cancel_fn)

      assert_raise RuntimeError, "boom", fn ->
        Enum.to_list(wrapped)
      end

      # after_fn fires on raise (Enum.reduce internal try/after) and
      # always calls cancel to release the Finch connection.
      assert_receive :cancel_called, 500
    end

    test "calls cancel_fn on partial consumption via Enum.take" do
      test_pid = self()
      cancel_fn = fn -> send(test_pid, :cancel_called) end

      result =
        Stream.iterate(1, &(&1 + 1))
        |> StreamCleanup.wrap_stream(cancel_fn)
        |> Enum.take(3)

      assert result == [1, 2, 3]
      # after_fn fires on halt (Enum.take) and calls cancel.
      assert_receive :cancel_called, 500
    end

    test "cleanup process does not outlive the stream" do
      test_pid = self()
      cancel_fn = fn -> send(test_pid, :cancel_called) end

      # Consume a stream to completion
      [1, 2, 3]
      |> StreamCleanup.wrap_stream(cancel_fn)
      |> Enum.to_list()

      # Give the cleanup process time to terminate
      Process.sleep(50)

      # cancel is called exactly once by after_fn; cleanup process receives
      # :stream_done and exits. Verify no second cancel call arrives.
      assert_receive :cancel_called, 100
      refute_receive :cancel_called, 100
    end

    test "cancel_fn errors are handled gracefully" do
      cancel_fn = fn -> raise "cancel exploded" end

      consumer =
        spawn(fn ->
          Stream.repeatedly(fn ->
            Process.sleep(100)
            :tick
          end)
          |> StreamCleanup.wrap_stream(cancel_fn)
          |> Enum.take(100)
        end)

      Process.sleep(50)
      ref = Process.monitor(consumer)

      # Kill the consumer — cleanup should handle the raise gracefully
      Process.exit(consumer, :cancelled)

      # The consumer process should exit (it was killed)
      assert_receive {:DOWN, ^ref, :process, ^consumer, :cancelled}, 1_000

      # No crash, no hanging — the cleanup process caught the error
    end

    test "calls cancel_fn even on :kill signal (propagates as :killed to linked cleanup)" do
      test_pid = self()
      cancel_fn = fn -> send(test_pid, :cancel_called) end

      consumer =
        spawn(fn ->
          Stream.repeatedly(fn ->
            Process.sleep(100)
            :tick
          end)
          |> StreamCleanup.wrap_stream(cancel_fn)
          |> Enum.take(100)
        end)

      Process.sleep(50)
      Process.exit(consumer, :kill)

      # :kill is untrappable for the target process, but propagates as
      # :killed to linked processes — and :killed CAN be trapped.
      # The cleanup process receives {:EXIT, caller, :killed} and calls cancel.
      assert_receive :cancel_called, 1_000
    end

    test "works with empty streams" do
      test_pid = self()
      cancel_fn = fn -> send(test_pid, :cancel_called) end

      result =
        []
        |> StreamCleanup.wrap_stream(cancel_fn)
        |> Enum.to_list()

      assert result == []
      # after_fn fires even for empty streams and calls cancel.
      assert_receive :cancel_called, 500
    end

    test "preserves stream laziness" do
      cancel_fn = fn -> :ok end

      # This stream should not be eagerly consumed
      counter = :counters.new(1, [:atomics])

      lazy_stream =
        Stream.repeatedly(fn ->
          :counters.add(counter, 1, 1)
          :counters.get(counter, 1)
        end)

      wrapped = StreamCleanup.wrap_stream(lazy_stream, cancel_fn)
      result = Enum.take(wrapped, 3)

      assert result == [1, 2, 3]
      # Only 3 elements should have been produced
      assert :counters.get(counter, 1) == 3
    end

    test "supports sequential wrap_stream calls in the same process" do
      test_pid = self()

      # First stream
      cancel_fn_1 = fn -> send(test_pid, {:cancel_called, 1}) end

      result_1 =
        [1, 2, 3]
        |> StreamCleanup.wrap_stream(cancel_fn_1)
        |> Enum.to_list()

      assert result_1 == [1, 2, 3]
      assert_receive {:cancel_called, 1}, 500

      # Second stream in the same process — cleanup from first must not interfere
      cancel_fn_2 = fn -> send(test_pid, {:cancel_called, 2}) end

      result_2 =
        [4, 5, 6]
        |> StreamCleanup.wrap_stream(cancel_fn_2)
        |> Enum.to_list()

      assert result_2 == [4, 5, 6]
      assert_receive {:cancel_called, 2}, 500
    end
  end
end
