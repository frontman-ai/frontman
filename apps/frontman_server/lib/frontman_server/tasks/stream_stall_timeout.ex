defmodule FrontmanServer.Tasks.StreamStallTimeout do
  require Logger

  defmodule Error do
    defexception [:timeout_ms]

    @impl true
    def message(%{timeout_ms: ms}) do
      "LLM stream stalled — no data received for #{ms}ms"
    end
  end

  def wrap_stream(stream, opts) when is_list(opts) do
    stall_timeout_ms = Keyword.fetch!(opts, :stall_timeout_ms)

    Stream.resource(
      fn -> start_feeder(stream) end,
      fn feeder_pid -> next_chunk(feeder_pid, stall_timeout_ms) end,
      fn feeder_pid -> stop_feeder(feeder_pid) end
    )
  end

  @feeder_ready_timeout_ms 5_000

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
        Logger.warning(
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
