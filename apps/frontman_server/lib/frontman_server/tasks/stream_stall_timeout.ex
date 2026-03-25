defmodule FrontmanServer.Tasks.StreamStallTimeout do
  @moduledoc """
  Detects silent LLM stream stalls by enforcing a per-chunk deadline.

  When an LLM provider silently stalls (no chunks, no TCP error), the
  downstream `StreamServer.next/2` GenServer.call eventually times out
  with an unhandled EXIT. This module fires before that happens, raising
  a clear `StreamStallTimeout.Error` that can be caught and surfaced
  to the user.

  ## How it works

  A linked feeder process consumes the inner stream and sends chunks
  via messages. The consumer pulls chunks with `receive ... after timeout`.
  If no chunk arrives within the deadline, `StreamStallTimeout.Error` is
  raised. The feeder is killed on timeout or when the stream completes.
  """

  require Logger

  defmodule Error do
    @moduledoc "Raised when no LLM stream chunk arrives within the stall timeout."
    defexception [:timeout_ms]

    @impl true
    def message(%{timeout_ms: ms}) do
      "LLM stream stalled — no data received for #{ms}ms"
    end
  end

  @doc """
  Wraps a stream with per-chunk stall detection.

  Returns a new stream that behaves identically to the input but raises
  `StreamStallTimeout.Error` if no chunk arrives within `stall_timeout_ms`.

  Must be wired before `StreamCleanup.wrap_stream/2` so that when the
  timeout raises, StreamCleanup's after callback fires and releases the
  Finch connection.

  ## Options

    - `:stall_timeout_ms` — required, max time to wait for a chunk (ms)
  """
  @spec wrap_stream(Enumerable.t(), keyword()) :: Enumerable.t()
  def wrap_stream(stream, opts) when is_list(opts) do
    stall_timeout_ms = Keyword.fetch!(opts, :stall_timeout_ms)

    Stream.resource(
      fn -> start_feeder(stream) end,
      fn feeder_pid -> next_chunk(feeder_pid, stall_timeout_ms) end,
      fn feeder_pid -> stop_feeder(feeder_pid) end
    )
  end

  # Max time to wait for the feeder process ready handshake.
  @feeder_ready_timeout_ms 5_000

  # Spawns a linked feeder process that consumes the inner stream and
  # forwards chunks to the caller via messages.
  #
  # Uses a ready handshake (like StreamCleanup) to guarantee the feeder
  # is set up before we return.
  @spec start_feeder(Enumerable.t()) :: pid()
  defp start_feeder(stream) do
    caller = self()

    pid =
      spawn_link(fn ->
        send(caller, {:feeder_ready, self()})

        try do
          Enum.each(stream, fn chunk ->
            send(caller, {:stream_chunk, self(), chunk})
          end)

          send(caller, {:stream_done, self()})
        rescue
          e ->
            send(caller, {:stream_error, self(), {:exception, e, __STACKTRACE__}})
        catch
          kind, reason ->
            send(caller, {:stream_error, self(), {kind, reason, __STACKTRACE__}})
        end
      end)

    receive do
      {:feeder_ready, ^pid} -> pid
    after
      @feeder_ready_timeout_ms ->
        raise "StreamStallTimeout: feeder process did not start within #{@feeder_ready_timeout_ms}ms"
    end
  end

  defp next_chunk(feeder_pid, stall_timeout_ms) when is_integer(stall_timeout_ms) do
    receive do
      {:stream_chunk, ^feeder_pid, chunk} ->
        {[chunk], feeder_pid}

      {:stream_done, ^feeder_pid} ->
        {:halt, feeder_pid}

      {:stream_error, ^feeder_pid, {:exception, e, stacktrace}} ->
        reraise e, stacktrace

      {:stream_error, ^feeder_pid, {kind, reason, stacktrace}} ->
        :erlang.raise(kind, reason, stacktrace)
    after
      stall_timeout_ms ->
        Logger.error(
          "StreamStallTimeout: no chunk received for #{stall_timeout_ms}ms, aborting stream"
        )

        raise Error, timeout_ms: stall_timeout_ms
    end
  end

  defp stop_feeder(feeder_pid) when is_pid(feeder_pid) do
    case Process.alive?(feeder_pid) do
      true ->
        Process.unlink(feeder_pid)
        Process.exit(feeder_pid, :kill)

      false ->
        :ok
    end
  end
end
