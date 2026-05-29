defmodule SwarmAi.ExecutionWorker do
  @moduledoc false

  use GenServer, restart: :temporary
  use TypedStruct

  require Logger

  @type dispatcher :: nil | {module(), atom(), list()}

  @type task :: %{
          required(:agent) => SwarmAi.Agent.t()
        }

  typedstruct enforce: true do
    field(:runtime, atom())
    field(:registry, atom())
    field(:dispatcher, dispatcher())
    field(:context, map())
    field(:agent, SwarmAi.Agent.t())
    field(:watcher, pid())
    field(:callback_opts, SwarmAi.Executor.opts())
  end

  @spec start_link(dispatcher(), {atom(), task()}) :: GenServer.on_start()
  def start_link(event_dispatcher, {runtime, task}) do
    registry = SwarmAi.registry_name(runtime)

    name =
      {:via, Registry, {registry, SwarmAi.running_execution_registry_entry_for_agent(task.agent)}}

    GenServer.start_link(__MODULE__, {runtime, event_dispatcher, task}, name: name)
  end

  @impl true
  def init({runtime, event_dispatcher, task}) do
    registry = SwarmAi.registry_name(runtime)
    context = SwarmAi.Agent.context(task.agent)
    watcher = spawn_death_watcher(event_dispatcher, task.agent, context)

    state = %__MODULE__{
      runtime: runtime,
      registry: registry,
      dispatcher: event_dispatcher,
      context: context,
      agent: task.agent,
      watcher: watcher,
      callback_opts: build_callback_opts(event_dispatcher, task.agent, context, watcher)
    }

    {:ok, state, {:continue, :run}}
  end

  @impl true
  def handle_continue(:run, %__MODULE__{} = state) do
    registry_entry = SwarmAi.running_execution_registry_entry_for_agent(state.agent)

    try do
      result = SwarmAi.Executor.run(state.runtime, state.agent, state.callback_opts)

      # Unregister before dispatch so running?/2 returns false first.
      Registry.unregister(state.registry, registry_entry)
      send(state.watcher, :completed)

      case result do
        {:ok, _, _} = ok ->
          dispatch_agent_event(state.dispatcher, state.agent, {:completed, ok}, state.context)

        {:error, _, _} = error ->
          dispatch_agent_event(state.dispatcher, state.agent, {:failed, error}, state.context)

        {:paused, {:pause_agent, tool_call_id, tool_name, timeout_ms} = reason} ->
          :telemetry.execute(
            [:swarm_ai, :runtime, :paused],
            %{count: 1},
            %{agent_id: SwarmAi.Agent.id(state.agent), reason: reason}
          )

          dispatch_agent_event(
            state.dispatcher,
            state.agent,
            {:paused, {:timeout, tool_call_id, tool_name, timeout_ms}},
            state.context
          )
      end
    after
      # Safety net, idempotent if already unregistered above.
      Registry.unregister(state.registry, registry_entry)
    end

    {:stop, :normal, state}
  end

  defp build_callback_opts(nil, _agent, _context, _watcher), do: []

  defp build_callback_opts(dispatcher, agent, context, watcher) do
    [
      on_chunk: fn chunk ->
        dispatch_agent_event(dispatcher, agent, {:chunk, chunk}, context)
      end,
      on_response: fn response ->
        send(watcher, {:snapshot, response})
        dispatch_agent_event(dispatcher, agent, {:response, response}, context)
      end,
      on_tool_call: fn tool_call ->
        dispatch_agent_event(dispatcher, agent, {:tool_call, tool_call}, context)
      end
    ]
  end

  # Spawns a linked watcher process that observes this worker for unexpected
  # death. Waits for readiness so trap_exit is set before execution proceeds.
  defp spawn_death_watcher(dispatcher, agent, context) do
    worker = self()

    pid =
      spawn_link(fn ->
        Process.flag(:trap_exit, true)
        send(worker, {:watcher_ready, self()})
        watcher_loop(worker, dispatcher, agent, context, nil)
      end)

    receive do
      {:watcher_ready, ^pid} -> pid
    after
      5_000 -> raise "SwarmAi death watcher failed to start"
    end
  end

  defp watcher_loop(worker, dispatcher, agent, context, loop_snapshot) do
    receive do
      {:snapshot, response} ->
        watcher_loop(worker, dispatcher, agent, context, response)

      :completed ->
        :ok

      {:EXIT, ^worker, reason} ->
        case reason do
          :normal ->
            :ok

          :cancelled ->
            Logger.info("Execution cancelled for #{inspect(SwarmAi.Agent.id(agent))}")
            dispatch_agent_event(dispatcher, agent, {:cancelled, %{loop: loop_snapshot}}, context)

          :shutdown ->
            Logger.info(
              "Execution terminated by supervisor for #{inspect(SwarmAi.Agent.id(agent))}, reason: :shutdown"
            )

            dispatch_agent_event(
              dispatcher,
              agent,
              {:terminated, %{loop: loop_snapshot}},
              context
            )

          {:shutdown, _} = reason ->
            Logger.info(
              "Execution terminated by supervisor for #{inspect(SwarmAi.Agent.id(agent))}, reason: #{inspect(reason)}"
            )

            dispatch_agent_event(
              dispatcher,
              agent,
              {:terminated, %{loop: loop_snapshot}},
              context
            )

          reason ->
            {crash_reason, stacktrace} = normalize_crash_reason(reason)

            Logger.warning(
              "Execution crashed for #{inspect(SwarmAi.Agent.id(agent))}, reason: #{inspect(reason)}"
            )

            dispatch_agent_event(
              dispatcher,
              agent,
              {:crashed, %{reason: crash_reason, stacktrace: stacktrace, loop: loop_snapshot}},
              context
            )

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

  defp dispatch_agent_event(dispatcher, agent, event, context) do
    dispatch_event(dispatcher, SwarmAi.Agent.id(agent), event, context)
  end

  defp dispatch_event(nil, _agent_id, _event, _context), do: :ok

  defp dispatch_event({mod, fun, args}, agent_id, event, context) do
    apply(mod, fun, args ++ [agent_id, event, context])
    :ok
  rescue
    error ->
      # Dispatch failures must not crash the watcher or block cleanup.
      Logger.error("SwarmAi event dispatch failed: #{Exception.message(error)}")
      {:error, error}
  end
end
