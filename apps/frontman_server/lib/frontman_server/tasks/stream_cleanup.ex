defmodule FrontmanServer.Tasks.StreamCleanup do
  @moduledoc """
  Ensures LLM streaming connections are released when the consuming process
  dies unexpectedly (cancellation, crash).

  ## Problem

  `ReqLLM.stream_text/3` returns a `cancel` function that releases the
  underlying Finch HTTP connection. If the process consuming the stream is
  killed (e.g. via `Process.exit(pid, :cancelled)`), the cancel function is
  never called and the connection is leaked back into the Finch pool only
  after the provider-side timeout (up to 150 s with our `receive_timeout`).

  Under concurrent load this exhausts the connection pool.

  ## Solution

  `wrap_stream/2` uses two complementary mechanisms:

  1. **`Stream.transform` after callback** — fires on normal completion,
     `Enum.take` halt, and raise during consumption. Calls `cancel_fn`
     directly (idempotent) and signals the cleanup process to stand down.

  2. **Linked cleanup process** — traps exits from the caller. If the
     caller dies before the stream's after callback fires (e.g.
     `Process.exit(pid, :cancelled)`), the cleanup process calls
     `cancel_fn` as a safety net.

  The cancel function is idempotent, so double-calling is harmless.

  See https://github.com/frontman-ai/frontman/issues/428
  """

  require Logger

  @doc """
  Wraps a stream with connection cleanup tied to the calling process lifecycle.

  Returns a new stream that behaves identically to `stream` but guarantees
  `cancel_fn` is called when:

  - the stream is fully consumed
  - the stream is partially consumed (e.g. `Enum.take`)
  - an error is raised during consumption
  - the consumer process is killed before consumption completes

  ## Parameters

    - `stream` — the lazy chunk stream from ReqLLM
    - `cancel_fn` — 0-arity function that releases the underlying connection.
      Typically `response.cancel` from `ReqLLM.stream_text/3`.

  """
  @spec wrap_stream(Enumerable.t(), (-> any())) :: Enumerable.t()
  def wrap_stream(stream, cancel_fn) when is_function(cancel_fn, 0) do
    cleanup_pid = spawn_link_cleanup(cancel_fn)

    Stream.transform(
      stream,
      fn -> :ok end,
      fn chunk, acc -> {[chunk], acc} end,
      fn _acc ->
        # Stream ended (normal, halt via Enum.take, or raise).
        # Always cancel to release the Finch connection immediately.
        do_cancel(cancel_fn)

        # Tell the cleanup process it can exit — we already handled it.
        send(cleanup_pid, :stream_done)
      end
    )
  end

  # Spawns a process linked to the caller that holds the cancel function.
  #
  # Uses a synchronization handshake to guarantee `trap_exit` is set before
  # the caller can proceed (and potentially be killed). Without this, there
  # is a race window between `spawn_link` returning and the child setting
  # `trap_exit` where a kill signal would terminate the cleanup process.
  #
  # - `:stream_done` → after callback already cancelled, exit cleanly
  # - `{:EXIT, caller, _}` → caller died before after_fn, cancel as safety net
  @spec spawn_link_cleanup((-> any())) :: pid()
  defp spawn_link_cleanup(cancel_fn) do
    caller = self()

    pid =
      spawn_link(fn ->
        Process.flag(:trap_exit, true)
        send(caller, {:cleanup_ready, self()})

        receive do
          :stream_done ->
            # after_fn already called cancel, nothing to do.
            :ok

          {:EXIT, ^caller, _reason} ->
            # Caller died (cancel / crash) before stream after_fn could fire.
            # Release the Finch connection as safety net.
            do_cancel(cancel_fn)
        end
      end)

    receive do
      {:cleanup_ready, ^pid} -> pid
    end
  end

  defp do_cancel(cancel_fn) do
    cancel_fn.()
  rescue
    e ->
      Logger.warning("StreamCleanup: cancel raised #{Exception.message(e)}")
  catch
    kind, reason ->
      Logger.warning("StreamCleanup: cancel failed #{inspect({kind, reason})}")
  end
end
