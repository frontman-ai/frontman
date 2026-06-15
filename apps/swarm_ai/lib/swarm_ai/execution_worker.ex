defmodule SwarmAi.ExecutionWorker do
  @moduledoc false

  use GenServer, restart: :temporary
  use TypedStruct

  require Logger

  typedstruct enforce: true do
    field(:runtime, atom())
    field(:loop, SwarmAi.Loop.t())
  end

  @spec start_link(dispatcher(), {atom(), SwarmAi.Agent.t()}) :: GenServer.on_start()
  def start_link(event_dispatcher, {runtime, agent}) do
    registry = SwarmAi.registry_name(runtime)

    name =
      {:via, Registry, {registry, SwarmAi.running_execution_registry_entry_for_agent(agent)}}

    GenServer.start_link(__MODULE__, {runtime, agent, event_dispatcher}, name: name)
  end

  @impl true
  def init({runtime, agent, event_dispatcher}) do
    state = %__MODULE__{
      runtime: runtime,
      agent: agent,
      event_dispatcher: event_dispatcher
    }

    {:ok, state, {:continue, :run}}
  end

  @impl true
  def handle_continue(:run, %__MODULE__{} = state) do
    registry = SwarmAi.registry_name(state.runtime)

    agent_id = SwarmAi.Agent.id(state.agent)
    agent_context = SwarmAi.Agent.context(state.agent)
    event_dispatcher = state.event_dispatcher

    spawn_death_watcher(agent_id, agent_context, event_dispatcher)

    try do
      event = SwarmAi.Executor.run(loop)

      unregister(registry, state.agent)
      dispatch_event(event_dispatcher, agent_id, agent_context, event)
    after
      unregister(registry, state.agent)
      # Safety net, idempotent if already unregistered above.
    end

    {:stop, :normal, state}
  end

  defp unregister(registry, agent) do
    registry_entry = SwarmAi.running_execution_registry_entry_for_agent(agent)
    Registry.unregister(registry, registry_entry)
  end

  defp spawn_death_watcher(agent_id, agent_context, event_dispatcher) do
    worker_pid = self()

    pid =
      spawn(fn ->
        try do
          monitor_ref = Process.monitor(worker_pid)
          send(worker_pid, {:watcher_ready, self()})
          watcher_loop(monitor_ref, worker_pid, agent_id, agent_context, event_dispatcher)
        rescue
          error ->
            Logger.error(
              "SwarmAi death watcher crashed: #{Exception.format(:error, error, __STACKTRACE__)}"
            )
        catch
          :exit, reason ->
            Logger.error("SwarmAi death watcher exited: #{Exception.format_exit(reason)}")

          :throw, reason ->
            Logger.error("SwarmAi death watcher threw: #{inspect(reason)}")
        end
      end)

    receive do
      {:watcher_ready, ^pid} -> pid
    after
      5_000 -> raise "SwarmAi death watcher failed to start"
    end
  end

  defp watcher_loop(monitor_ref, worker_pid, agent_id, agent_context, event_dispatcher) do
    receive do
      {:DOWN, ^monitor_ref, :process, ^worker_pid, :normal} ->
        :ok

      {:DOWN, ^monitor_ref, :process, ^worker_pid, :cancelled} ->
        Logger.info("Execution cancelled for #{agent_id}")
        event = {:cancelled, nil}
        dispatch_event(event_dispatcher, agent_id, agent_context, event)

      {:DOWN, ^monitor_ref, :process, ^worker_pid, :shutdown} ->
        Logger.info("Execution terminated by supervisor for #{agent_id}, reason: :shutdown")
        event = {:terminated, nil}
        dispatch_event(event_dispatcher, agent_id, agent_context, event)

      {:DOWN, ^monitor_ref, :process, ^worker_pid, {:shutdown, reason}} ->
        Logger.info(fn ->
          "Execution terminated by supervisor for #{agent_id}, reason: #{inspect(reason)}"
        end)

        event = {:terminated, reason}
        dispatch_event(event_dispatcher, agent_id, agent_context, event)

      {:DOWN, ^monitor_ref, :process, ^worker_pid, reason} ->
        message = Exception.format_exit(reason)
        Logger.warning(fn -> "Execution crashed for #{agent_id}, reason: #{inspect(reason)}" end)
        event = {:crashed, %{message: message}}
        dispatch_event(event_dispatcher, agent_id, agent_context, event)

      _other ->
        # Draining unrelated messages
        watcher_loop(monitor_ref, worker_pid, agent_id, agent_context, event_dispatcher)
    end
  end

  defp dispatch_event({mod, fun, args}, agent_id, agent_context, event) do
    apply(mod, fun, args ++ [agent_id, event, agent_context])
  rescue
    error ->
      Logger.error("SwarmAi event dispatch failed: #{Exception.message(error)}")
      {:error, error}
  end
end
