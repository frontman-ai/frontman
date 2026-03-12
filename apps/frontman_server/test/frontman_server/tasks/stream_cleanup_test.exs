defmodule FrontmanServer.Tasks.StreamCleanupTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.StreamCleanup
  alias SwarmAi.LLM.{Chunk, Response, Usage}

  # ---------------------------------------------------------------------------
  # Integration test LLM — implements SwarmAi.LLM protocol with StreamCleanup
  #
  # Mimics the real LLMClient production pipeline:
  #   1. Creates a Stream.resource (like ReqLLM.stream_text/3)
  #   2. Wraps it with StreamCleanup.wrap_stream(cancel_fn)
  #   3. Returns {:ok, wrapped_stream}
  #
  # The `cancel_pid` field receives :cancel_called when cleanup fires,
  # allowing tests to verify connection release.
  # ---------------------------------------------------------------------------

  defmodule CleanupTrackingLLM do
    @moduledoc false
    defstruct [:cancel_pid, :chunks, :delay_ms, :error_after, :notify_started]
  end

  defimpl SwarmAi.LLM, for: FrontmanServer.Tasks.StreamCleanupTest.CleanupTrackingLLM do
    alias FrontmanServer.Tasks.StreamCleanup

    def stream(
          %{
            cancel_pid: cancel_pid,
            chunks: chunks,
            delay_ms: delay_ms,
            error_after: error_after,
            notify_started: notify_started
          },
          _messages,
          _opts
        ) do
      cancel_fn = fn -> send(cancel_pid, :cancel_called) end

      # Simulate a ReqLLM-style Stream.resource that yields chunks lazily
      raw_stream =
        Stream.resource(
          fn -> {chunks, 0, false} end,
          fn
            {[], _index, _notified} ->
              {:halt, :done}

            {[chunk | rest], index, notified} ->
              if error_after && index >= error_after do
                raise "LLM stream error"
              end

              # Notify the test process once when the first chunk is about to
              # be emitted, proving the stream is actively being consumed.
              notified =
                if !notified && notify_started do
                  send(notify_started, :stream_started)
                  true
                else
                  notified
                end

              if delay_ms && delay_ms > 0, do: Process.sleep(delay_ms)
              {[chunk], {rest, index + 1, notified}}
          end,
          fn _ -> :ok end
        )

      wrapped = StreamCleanup.wrap_stream(raw_stream, cancel_fn)
      {:ok, wrapped}
    end
  end

  # Helper to build standard chunk sequences for integration tests
  defp standard_chunks(text) do
    [
      Chunk.token(text),
      Chunk.usage(%Usage{input_tokens: 10, output_tokens: 5}),
      Chunk.done(:stop)
    ]
  end

  defp user_message do
    SwarmAi.Message.user("test input")
  end

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

  # ==========================================================================
  # Integration tests: SwarmAi.LLM protocol → Response.from_stream pipeline
  #
  # These tests exercise StreamCleanup through the real production consumption
  # path. CleanupTrackingLLM implements SwarmAi.LLM, wraps the chunk stream
  # with StreamCleanup.wrap_stream (just like LLMClient does), and the stream
  # is consumed via Response.from_stream/1 (the same Enum.reduce path used by
  # SwarmAi.execute_llm_call).
  # ==========================================================================

  describe "integration: SwarmAi.LLM protocol → Response.from_stream" do
    test "cancel_fn fires after normal stream consumption through Response.from_stream" do
      llm = %CleanupTrackingLLM{
        cancel_pid: self(),
        chunks: standard_chunks("Hello world"),
        delay_ms: 0,
        error_after: nil
      }

      {:ok, stream} = SwarmAi.LLM.stream(llm, [user_message()], [])
      response = Response.from_stream(stream)

      assert response.content == "Hello world"
      assert response.finish_reason == :stop
      assert response.usage == %Usage{input_tokens: 10, output_tokens: 5}

      # Connection released via after_fn
      assert_receive :cancel_called, 500
    end

    test "cancel_fn fires when consumer process is killed mid-stream" do
      test_pid = self()

      # Slow stream — gives us time to kill the consumer
      llm = %CleanupTrackingLLM{
        cancel_pid: test_pid,
        chunks: List.duplicate(Chunk.token("tok"), 100) ++ [Chunk.done(:stop)],
        delay_ms: 50,
        error_after: nil,
        notify_started: test_pid
      }

      consumer =
        spawn(fn ->
          {:ok, stream} = SwarmAi.LLM.stream(llm, [user_message()], [])
          Response.from_stream(stream)
        end)

      # Wait until the stream is actively producing chunks (no fixed sleep)
      assert_receive :stream_started, 5_000

      # Simulate Runtime.cancel/2 — the exact kill signal used in production
      Process.exit(consumer, :cancelled)

      # Cleanup process catches the EXIT and calls cancel_fn
      # Use a generous timeout to avoid CI flakiness under load
      assert_receive :cancel_called, 5_000
    end

    test "cancel_fn fires when stream raises mid-consumption through Response.from_stream" do
      llm = %CleanupTrackingLLM{
        cancel_pid: self(),
        chunks: standard_chunks("partial"),
        delay_ms: 0,
        # Raise after the first chunk (token)
        error_after: 1
      }

      {:ok, stream} = SwarmAi.LLM.stream(llm, [user_message()], [])

      assert_raise RuntimeError, "LLM stream error", fn ->
        Response.from_stream(stream)
      end

      # after_fn fires on raise, releasing the connection
      assert_receive :cancel_called, 500
    end

    test "cancel_fn fires with Stream.each callback (mirrors execute_llm_call pipeline)" do
      # In production, SwarmAi wraps the stream with Stream.each(on_chunk)
      # before passing to Response.from_stream. Verify cleanup still works.
      collected_chunks = :ets.new(:chunks, [:bag, :public])

      llm = %CleanupTrackingLLM{
        cancel_pid: self(),
        chunks: standard_chunks("streamed"),
        delay_ms: 0,
        error_after: nil
      }

      {:ok, stream} = SwarmAi.LLM.stream(llm, [user_message()], [])

      stream_with_callback =
        Stream.each(stream, fn chunk ->
          :ets.insert(collected_chunks, {chunk.type, chunk})
        end)

      response = Response.from_stream(stream_with_callback)

      assert response.content == "streamed"

      # Verify the callback was invoked (chunks were observed)
      assert :ets.lookup(collected_chunks, :token) != []
      assert :ets.lookup(collected_chunks, :done) != []

      # Connection released
      assert_receive :cancel_called, 500

      :ets.delete(collected_chunks)
    end

    test "cancel_fn fires when :kill signal terminates consumer mid-stream" do
      test_pid = self()

      llm = %CleanupTrackingLLM{
        cancel_pid: test_pid,
        chunks: List.duplicate(Chunk.token("tok"), 100) ++ [Chunk.done(:stop)],
        delay_ms: 50,
        error_after: nil,
        notify_started: test_pid
      }

      consumer =
        spawn(fn ->
          {:ok, stream} = SwarmAi.LLM.stream(llm, [user_message()], [])
          Response.from_stream(stream)
        end)

      # Wait until the stream is actively producing chunks (no fixed sleep)
      assert_receive :stream_started, 5_000

      # :kill is untrappable by the target, but propagates as :killed to
      # linked processes — the cleanup process can trap :killed.
      Process.exit(consumer, :kill)

      assert_receive :cancel_called, 1_000
    end

    test "cancel_fn fires exactly once on normal consumption (no double-call)" do
      llm = %CleanupTrackingLLM{
        cancel_pid: self(),
        chunks: standard_chunks("once"),
        delay_ms: 0,
        error_after: nil
      }

      {:ok, stream} = SwarmAi.LLM.stream(llm, [user_message()], [])
      _response = Response.from_stream(stream)

      # after_fn calls cancel; cleanup process receives :stream_done and exits
      # without calling cancel again.
      assert_receive :cancel_called, 500
      Process.sleep(50)
      refute_receive :cancel_called, 100
    end

    test "sequential LLM calls through the protocol each clean up independently" do
      for i <- 1..3 do
        llm = %CleanupTrackingLLM{
          cancel_pid: self(),
          chunks: standard_chunks("call #{i}"),
          delay_ms: 0,
          error_after: nil
        }

        {:ok, stream} = SwarmAi.LLM.stream(llm, [user_message()], [])
        response = Response.from_stream(stream)

        assert response.content == "call #{i}"
        assert_receive :cancel_called, 500
      end

      # No stale cancel messages from previous iterations
      Process.sleep(50)
      refute_receive :cancel_called, 100
    end
  end
end
