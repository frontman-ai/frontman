defmodule SwarmAi.ExecutionWorker do
  @moduledoc false

  use GenServer, restart: :temporary
  use TypedStruct

  require Logger

  @type dispatcher :: nil | {module(), atom(), list()}
  @type dispatch_event :: SwarmAi.Executor.dispatch_event()

  typedstruct enforce: true do
    field(:runtime, atom())
    field(:agent, SwarmAi.Agent.t())
    field(:watcher, pid())
    field(:dispatch_event, dispatch_event())
  end

  @spec start_link(dispatcher(), {atom(), SwarmAi.Agent.t()}) :: GenServer.on_start()
  def start_link(event_dispatcher, {runtime, agent}) do
    registry = SwarmAi.registry_name(runtime)

    name =
      {:via, Registry, {registry, SwarmAi.running_execution_registry_entry_for_agent(agent)}}

    GenServer.start_link(__MODULE__, {runtime, event_dispatcher, agent}, name: name)
  end

  @impl true
  def init({runtime, event_dispatcher, agent}) do
    dispatch_event = build_dispatch_event(event_dispatcher, agent)
    death_watcher = spawn_death_watcher(agent, dispatch_event)

    state = %__MODULE__{
      runtime: runtime,
      agent: agent,
      watcher: death_watcher,
      dispatch_event: dispatch_event
    }

    {:ok, state, {:continue, :run}}
  end

  @impl true
  def handle_continue(:run, %__MODULE__{} = state) do
    registry_entry = SwarmAi.running_execution_registry_entry_for_agent(state.agent)
    registry = SwarmAi.registry_name(state.runtime)

    try do
      event = SwarmAi.Executor.run(state.runtime, state.agent, state.dispatch_event)
      Registry.unregister(registry, registry_entry)
      send(state.watcher, :completed)
      state.dispatch_event.(event)
    after
      # Safety net, idempotent if already unregistered above.
      Registry.unregister(registry, registry_entry)
    end

    {:stop, :normal, state}
  end

  defp build_dispatch_event(nil, _agent), do: fn _event -> :ok end

  defp build_dispatch_event(dispatcher, agent) do
    agent_id = SwarmAi.Agent.id(agent)
    context = SwarmAi.Agent.context(agent)

    fn event -> dispatch_event(dispatcher, agent_id, event, context) end
  end

  # Spawns a linked watcher process that observes this worker for unexpected
  # death. Waits for readiness so trap_exit is set before execution proceeds.
  defp spawn_death_watcher(agent, dispatch_event) do
    worker = self()

    pid =
      spawn_link(fn ->
        Process.flag(:trap_exit, true)
        send(worker, {:watcher_ready, self()})
        watcher_loop(worker, agent, dispatch_event)
      end)

    receive do
      {:watcher_ready, ^pid} -> pid
    after
      5_000 -> raise "SwarmAi death watcher failed to start"
    end
  end

  defp watcher_loop(worker, agent, dispatch_event) do
    receive do
      :completed ->
        :ok

      {:EXIT, ^worker, reason} ->
        case reason do
          :normal ->
            :ok

          :cancelled ->
            Logger.info("Execution cancelled for #{inspect(SwarmAi.Agent.id(agent))}")
            dispatch_event.({:cancelled, nil})

          :shutdown ->
            Logger.info(
              "Execution terminated by supervisor for #{inspect(SwarmAi.Agent.id(agent))}, reason: :shutdown"
            )

            dispatch_event.({:terminated, nil})

          {:shutdown, _} = reason ->
            Logger.info(
              "Execution terminated by supervisor for #{inspect(SwarmAi.Agent.id(agent))}, reason: #{inspect(reason)}"
            )

            dispatch_event.({:terminated, nil})

          reason ->
            {crash_reason, stacktrace} = normalize_crash_reason(reason)

            Logger.warning(
              "Execution crashed for #{inspect(SwarmAi.Agent.id(agent))}, reason: #{inspect(reason)}"
            )

            dispatch_event.({:crashed, %{reason: crash_reason, stacktrace: stacktrace}})

            emit_telemetry(agent, worker, reason)
        end
    end
  end

  defp normalize_crash_reason({_exception, _stacktrace} = reason), do: reason
  defp normalize_crash_reason(reason), do: {reason, []}

  defp emit_telemetry(agent, pid, reason) do
    :telemetry.execute(
      [:swarm_ai, :runtime, :crash],
      %{count: 1},
      %{agent_id: SwarmAi.Agent.id(agent), pid: pid, reason: reason}
    )
  end

  defp dispatch_event({mod, fun, args}, agent_id, event, context) do
    apply(mod, fun, args ++ [agent_id, event, context])
  rescue
    error ->
      # Dispatch failures must not crash the watcher or block cleanup.
      Logger.error("SwarmAi event dispatch failed: #{Exception.message(error)}")
      {:error, error}
  end
end
