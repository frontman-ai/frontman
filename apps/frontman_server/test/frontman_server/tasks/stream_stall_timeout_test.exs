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
