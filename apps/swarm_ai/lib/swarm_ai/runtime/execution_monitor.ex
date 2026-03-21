defmodule SwarmAi.Runtime.ExecutionMonitor do
  @moduledoc """
  Monitors execution processes and dispatches events on unexpected exits.

  Ensures consumers are notified when an agent execution crashes unexpectedly,
  rather than being left waiting indefinitely. Follows OTP "let it crash" philosophy —
  we don't prevent crashes, we just make sure they're reported.

  ## Design

  - Uses synchronous registration to avoid race conditions
  - Recovers state on restart by scanning the Runtime Registry
  - Events are dispatched via an MFA tuple (`event_dispatcher`) provided at
    startup. Because the MFA is static config (atoms + terms), it survives
    GenServer restarts — eliminating the closure-loss race condition that
    existed with anonymous function callbacks.
  - Loop snapshots (last-known execution state) are stored in an ETS table
    owned by the Runtime Supervisor (survives monitor restarts). Execution
    processes write directly via `stash_snapshot/3` (no GenServer bottleneck).
    The `:DOWN` handler reads from ETS — no race with Registry cleanup.
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

  `metadata` is passed through to dispatched crash/cancel events, enabling
  the dispatcher to persist data without depending on the channel process.
  """
  @spec watch(atom(), term(), map()) :: :ok
  def watch(monitor, key, metadata \\ %{}) do
    GenServer.call(monitor, {:watch, self(), key, metadata})
  end

  @doc """
  Stashes the latest loop snapshot for crash forensics.

  Writes directly to ETS — no GenServer roundtrip, safe to call from
  the execution process on every response.
  """
  @spec stash_snapshot(atom(), term(), term()) :: :ok
  def stash_snapshot(monitor, key, snapshot) do
    :ets.insert(snapshot_table_name(monitor), {key, snapshot})
    :ok
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    registry = Keyword.fetch!(opts, :registry)
    event_dispatcher = Keyword.get(opts, :event_dispatcher)

    # Clear stale snapshots from a previous life (table is owned by the
    # Supervisor and survives our restarts).
    :ets.delete_all_objects(snapshot_table_name(name))

    # On startup (including after crash/restart), rebuild state from Registry.
    state = rebuild_monitors_from_registry(registry)

    if map_size(state.monitors) > 0 do
      Logger.info(
        "SwarmAi.Runtime.ExecutionMonitor started, recovered #{map_size(state.monitors)} existing executions"
      )
    end

    {:ok,
     state
     |> Map.put(:name, name)
     |> Map.put(:registry, registry)
     |> Map.put(:event_dispatcher, event_dispatcher)}
  end

  @impl true
  def handle_call({:watch, pid, key, metadata}, _from, state) do
    ref = Process.monitor(pid)
    {:reply, :ok, put_in(state, [:monitors, ref], %{key: key, metadata: metadata})}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, state) do
    {entry, monitors} = Map.pop(state.monitors, ref)

    case entry do
      %{key: key, metadata: metadata} ->
        loop_snapshot = pop_snapshot(state.name, key)

        cond do
          cancelled?(reason) ->
            Logger.info("Execution cancelled",
              key: inspect(key),
              pid: inspect(pid)
            )

            dispatch_event(
              state.event_dispatcher,
              key,
              {:cancelled, %{loop: loop_snapshot}},
              metadata
            )

          abnormal_exit?(reason) ->
            Logger.warning("Execution crashed",
              key: inspect(key),
              pid: inspect(pid),
              reason: inspect(reason)
            )

            {crash_reason, stacktrace} = normalize_crash_reason(reason)

            dispatch_event(
              state.event_dispatcher,
              key,
              {:crashed, %{reason: crash_reason, stacktrace: stacktrace, loop: loop_snapshot}},
              metadata
            )

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
          # Recovered processes don't have metadata — use empty map.
          Map.put(acc, ref, %{key: key, metadata: %{}})
        else
          acc
        end
      end)

    %{monitors: monitors}
  end

  defp pop_snapshot(monitor_name, key) do
    table = snapshot_table_name(monitor_name)

    case :ets.lookup(table, key) do
      [{^key, snapshot}] ->
        :ets.delete(table, key)
        snapshot

      [] ->
        nil
    end
  end

  @doc false
  def snapshot_table_name(monitor_name), do: :"#{monitor_name}.Snapshots"

  defp dispatch_event(nil, _key, _event, _metadata), do: :ok

  defp dispatch_event({mod, fun, args}, key, event, metadata) do
    apply(mod, fun, args ++ [key, event, metadata])
  rescue
    e ->
      Logger.error("ExecutionMonitor event dispatch failed: #{Exception.message(e)}")
  end

  defp cancelled?(:cancelled), do: true
  defp cancelled?(_), do: false

  defp abnormal_exit?(:normal), do: false
  defp abnormal_exit?(:shutdown), do: false
  defp abnormal_exit?({:shutdown, _}), do: false
  defp abnormal_exit?(:cancelled), do: false
  defp abnormal_exit?(_), do: true

  defp normalize_crash_reason({_exception, _stacktrace} = reason), do: reason
  defp normalize_crash_reason(reason), do: {reason, []}

  defp emit_telemetry(key, pid, reason) do
    :telemetry.execute(
      [:swarm_ai, :runtime, :crash],
      %{count: 1},
      %{key: key, pid: pid, reason: reason}
    )
  end
end
