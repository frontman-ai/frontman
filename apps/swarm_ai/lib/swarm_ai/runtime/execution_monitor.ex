defmodule SwarmAi.Runtime.ExecutionMonitor do
  @moduledoc """
  Monitors execution processes and invokes callbacks on unexpected exits.

  Ensures consumers are notified when an agent execution crashes unexpectedly,
  rather than being left waiting indefinitely. Follows OTP "let it crash" philosophy —
  we don't prevent crashes, we just make sure they're reported.

  ## Design

  - Uses synchronous registration to avoid race conditions
  - Recovers state on restart by scanning the Runtime Registry
  - Callbacks (`on_crash`, `on_cancelled`) are provided per-execution
  - Waits for Registry cleanup before invoking callbacks, preserving the
    `running?/2` invariant from `SwarmAi.Runtime`
  """
  use GenServer

  require Logger

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Watch an execution process for crashes. Blocks until monitor is established.

  Must be called from the execution process itself (uses `self()`).

  ## Options

  - `:on_crash` - Called with `{reason, stacktrace}` on unexpected crash
  - `:on_cancelled` - Called with no args on cancellation
  """
  @spec watch(atom(), term(), keyword()) :: :ok
  def watch(monitor, key, opts \\ []) do
    on_crash = Keyword.get(opts, :on_crash, fn _ -> :ok end)
    on_cancelled = Keyword.get(opts, :on_cancelled, fn -> :ok end)

    GenServer.call(monitor, {:watch, self(), key, on_crash, on_cancelled})
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    registry = Keyword.fetch!(opts, :registry)

    # On startup (including after crash/restart), rebuild state from Registry.
    # We can't recover callbacks on restart, so recovered executions will log
    # but not invoke callbacks. The window is tiny.
    state = rebuild_monitors_from_registry(registry)

    if map_size(state.monitors) > 0 do
      Logger.info(
        "SwarmAi.Runtime.ExecutionMonitor started, recovered #{map_size(state.monitors)} existing executions"
      )
    end

    {:ok, Map.put(state, :registry, registry)}
  end

  @impl true
  def handle_call({:watch, pid, key, on_crash, on_cancelled}, _from, state) do
    ref = Process.monitor(pid)

    entry = %{
      key: key,
      on_crash: on_crash,
      on_cancelled: on_cancelled
    }

    {:reply, :ok, put_in(state, [:monitors, ref], entry)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    {entry, monitors} = Map.pop(state.monitors, ref)

    case entry do
      %{key: key} ->
        # Wait for the Registry to process its own :DOWN and remove the entry.
        # Both Registry and ExecutionMonitor monitor the execution process, so
        # both receive :DOWN when it dies. Without this, callbacks can fire
        # before Registry cleanup completes, causing running?/2 to return true
        # when consumers check it from the callback. The normal completion path
        # (execute/8) doesn't have this issue because it calls
        # Registry.unregister synchronously before the callback.
        await_registry_cleanup(state.registry, {:running, key})

        cond do
          cancelled?(reason) ->
            Logger.info("Execution cancelled",
              key: inspect(key),
              pid: inspect(pid)
            )

            safe_invoke(entry.on_cancelled, [])

          abnormal_exit?(reason) ->
            Logger.warning("Execution crashed",
              key: inspect(key),
              pid: inspect(pid),
              reason: inspect(reason)
            )

            safe_invoke(entry.on_crash, [normalize_crash_reason(reason)])
            emit_telemetry(key, pid, reason)

          true ->
            :ok
        end

      _ ->
        :ok
    end

    {:noreply, %{state | monitors: monitors}}
  end

  # --- Private ---

  defp rebuild_monitors_from_registry(registry) do
    monitors =
      registry
      |> Registry.select([
        {{{:running, :"$1"}, :"$2", :_}, [], [{{:"$1", :"$2"}}]}
      ])
      |> Enum.reduce(%{}, fn {key, pid}, acc ->
        if Process.alive?(pid) do
          ref = Process.monitor(pid)

          # No callbacks available on recovery — will log but not invoke
          entry = %{
            key: key,
            on_crash: fn _ -> :ok end,
            on_cancelled: fn -> :ok end
          }

          Map.put(acc, ref, entry)
        else
          acc
        end
      end)

    %{monitors: monitors}
  end

  # Spins until the Registry has processed its :DOWN for the given key.
  # The execution process is already dead at this point, so the Registry
  # cleanup is guaranteed — we just need to let the Registry GenServer
  # process its :DOWN message. In practice this returns on the first
  # iteration (the Registry is fast).
  defp await_registry_cleanup(registry, key, attempts \\ 100)

  defp await_registry_cleanup(_registry, key, 0) do
    Logger.warning("Registry cleanup timed out for key #{inspect(key)}, proceeding with callback")
    :ok
  end

  defp await_registry_cleanup(registry, key, attempts) do
    case Registry.lookup(registry, key) do
      [] ->
        :ok

      _ ->
        Process.sleep(1)
        await_registry_cleanup(registry, key, attempts - 1)
    end
  end

  defp cancelled?(:cancelled), do: true
  defp cancelled?(_), do: false

  defp abnormal_exit?(:normal), do: false
  defp abnormal_exit?(:shutdown), do: false
  defp abnormal_exit?({:shutdown, _}), do: false
  defp abnormal_exit?(:cancelled), do: false
  defp abnormal_exit?(_), do: true

  # Normalize :DOWN reason to a consistent {reason, stacktrace} tuple.
  # OTP sends {exception, stacktrace} for raises, but bare atoms/terms for exit().
  defp normalize_crash_reason({_exception, _stacktrace} = reason), do: reason
  defp normalize_crash_reason(reason), do: {reason, []}

  defp safe_invoke(fun, args) do
    apply(fun, args)
  rescue
    e ->
      Logger.error("ExecutionMonitor callback failed: #{Exception.message(e)}")
  end

  defp emit_telemetry(key, pid, reason) do
    :telemetry.execute(
      [:swarm_ai, :runtime, :crash],
      %{count: 1},
      %{key: key, pid: pid, reason: reason}
    )
  end
end
