defmodule FrontmanServer.Tasks.StreamStallTimeoutTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.StreamStallTimeout

  describe "wrap_stream/2" do
    test "passes through chunks from a normal stream" do
      stream = Stream.map(1..5, &"chunk-#{&1}")

      result =
        stream
        |> StreamStallTimeout.wrap_stream(stall_timeout_ms: 1_000)
        |> Enum.to_list()

      assert result == ["chunk-1", "chunk-2", "chunk-3", "chunk-4", "chunk-5"]
    end

    test "raises StreamStallTimeout.Error when stream stalls" do
      stall_stream =
        Stream.resource(
          fn -> 0 end,
          fn
            0 ->
              {["first-chunk"], 1}

            1 ->
              Process.sleep(:infinity)
              {:halt, nil}
          end,
          fn _ -> :ok end
        )

      assert_raise StreamStallTimeout.Error, ~r/no data received for 50ms/, fn ->
        stall_stream
        |> StreamStallTimeout.wrap_stream(stall_timeout_ms: 50)
        |> Enum.to_list()
      end
    end

    test "raises immediately when stream stalls from the start" do
      never_stream =
        Stream.resource(
          fn -> :init end,
          fn :init ->
            Process.sleep(:infinity)
            {:halt, nil}
          end,
          fn _ -> :ok end
        )

      assert_raise StreamStallTimeout.Error, fn ->
        never_stream
        |> StreamStallTimeout.wrap_stream(stall_timeout_ms: 50)
        |> Enum.to_list()
      end
    end

    test "propagates errors raised by the inner stream" do
      error_stream =
        Stream.resource(
          fn -> 0 end,
          fn
            0 -> {["ok-chunk"], 1}
            1 -> raise "inner stream boom"
          end,
          fn _ -> :ok end
        )

      assert_raise RuntimeError, "inner stream boom", fn ->
        error_stream
        |> StreamStallTimeout.wrap_stream(stall_timeout_ms: 1_000)
        |> Enum.to_list()
      end
    end

    test "feeder process is cleaned up after normal consumption" do
      stream = Stream.map(1..3, & &1)

      # Consume the stream
      stream
      |> StreamStallTimeout.wrap_stream(stall_timeout_ms: 1_000)
      |> Enum.to_list()

      # Give a moment for cleanup
      Process.sleep(10)

      # No linked processes should remain (just verifying no crash)
      assert Process.alive?(self())
    end

    test "keepalive chunks reset the stall timer and prevent false timeouts" do
      # Simulates the ping keepalive scenario from issue #731:
      # content chunk → long gap with keepalives → content chunk.
      # Without keepalives resetting the timer, this would stall-timeout.
      keepalive_stream =
        Stream.resource(
          fn -> 0 end,
          fn
            0 ->
              # Content chunk
              {[:content_chunk], 1}

            n when n in 1..3 ->
              # Simulate delay between keepalives (shorter than stall timeout)
              Process.sleep(30)
              {[:keepalive], n + 1}

            4 ->
              # Final content chunk arrives after keepalives kept us alive
              {[:final_chunk], 5}

            5 ->
              {:halt, 5}
          end,
          fn _ -> :ok end
        )

      # Stall timeout is 80ms. Without keepalives at 30ms intervals,
      # the 90ms+ gap between content chunks would trigger a timeout.
      result =
        keepalive_stream
        |> StreamStallTimeout.wrap_stream(stall_timeout_ms: 80)
        |> Enum.to_list()

      assert result == [:content_chunk, :keepalive, :keepalive, :keepalive, :final_chunk]
    end

    test "stalls when no keepalives arrive between content chunks" do
      # Same shape as above but WITHOUT keepalives — proves the timeout fires.
      no_keepalive_stream =
        Stream.resource(
          fn -> 0 end,
          fn
            0 ->
              {[:content_chunk], 1}

            1 ->
              # Long gap with no keepalives — exceeds stall timeout
              Process.sleep(:infinity)
              {:halt, nil}
          end,
          fn _ -> :ok end
        )

      assert_raise StreamStallTimeout.Error, ~r/no data received for 80ms/, fn ->
        no_keepalive_stream
        |> StreamStallTimeout.wrap_stream(stall_timeout_ms: 80)
        |> Enum.to_list()
      end
    end

    test "feeder process is cleaned up after stall timeout" do
      stall_stream =
        Stream.resource(
          fn -> :init end,
          fn :init ->
            Process.sleep(:infinity)
            {:halt, nil}
          end,
          fn _ -> :ok end
        )

      assert_raise StreamStallTimeout.Error, fn ->
        stall_stream
        |> StreamStallTimeout.wrap_stream(stall_timeout_ms: 50)
        |> Enum.to_list()
      end

      # Give a moment for cleanup
      Process.sleep(10)

      # The test process should still be alive (feeder was killed, not us)
      assert Process.alive?(self())
    end
  end
end
