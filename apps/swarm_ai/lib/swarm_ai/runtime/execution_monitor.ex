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
  - Before dispatching crash/cancel events, reads the last-known execution
    state from the Runtime Registry for crash forensics.
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

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    registry = Keyword.fetch!(opts, :registry)
    event_dispatcher = Keyword.get(opts, :event_dispatcher)

    # On startup (including after crash/restart), rebuild state from Registry.
    # The event_dispatcher MFA comes from init opts (child spec config),
    # so it's always available — no closures to lose.
    state = rebuild_monitors_from_registry(registry)

    if map_size(state.monitors) > 0 do
      Logger.info(
        "SwarmAi.Runtime.ExecutionMonitor started, recovered #{map_size(state.monitors)} existing executions"
      )
    end

    {:ok,
     state
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
        # Read execution state BEFORE Registry cleanup removes the entry.
        # This gives crash events access to the last-known loop state.
        loop_snapshot = read_loop_snapshot(state.registry, key)

        # Wait for the Registry to process its own :DOWN and remove the entry.
        await_registry_cleanup(state.registry, {:running, key})

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
          # Persistence may be limited for these, but the process is
          # already running and was likely already persisted before restart.
          Map.put(acc, ref, %{key: key, metadata: %{}})
        else
          acc
        end
      end)

    %{monitors: monitors}
  end

  defp read_loop_snapshot(registry, key) do
    case Registry.lookup(registry, {:running, key}) do
      [{_pid, value}] when is_map(value) -> Map.get(value, :last_response)
      _ -> nil
    end
  end

  # Spins until the Registry has processed its :DOWN for the given key.
  defp await_registry_cleanup(registry, key, attempts \\ 100)

  defp await_registry_cleanup(_registry, key, 0) do
    Logger.warning("Registry cleanup timed out for key #{inspect(key)}, proceeding with dispatch")
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
