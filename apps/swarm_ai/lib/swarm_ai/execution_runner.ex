defmodule SwarmAi.ExecutionRunner do
  @moduledoc false

  require Logger

  defstruct [
    :registry,
    :dispatcher,
    :context,
    :agent,
    :watcher,
    :streaming_opts
  ]

  @type task :: %{
          required(:agent) => SwarmAi.Agent.t(),
          required(:context) => map()
        }

  @type t :: %__MODULE__{
          registry: atom(),
          dispatcher: nil | {module(), atom(), list()},
          context: map(),
          agent: SwarmAi.Agent.t(),
          watcher: pid(),
          streaming_opts: keyword()
        }

  @spec prepare(atom(), nil | {module(), atom(), list()}, task()) :: t()
  def prepare(runtime, dispatcher, task) do
    registry = SwarmAi.registry_name(runtime)
    task_sup = SwarmAi.task_supervisor_name(runtime)

    watcher = spawn_death_watcher(dispatcher, task.agent, task.context)

    tool_executor =
      task.agent
      |> SwarmAi.Agent.tool_executor()
      |> wrap_executor_with_supervised_execution(task_sup)

    streaming_opts =
      [tool_executor: tool_executor]
      |> build_streaming_opts(dispatcher, task.agent, task.context, watcher)

    %__MODULE__{
      registry: registry,
      dispatcher: dispatcher,
      context: task.context,
      agent: task.agent,
      watcher: watcher,
      streaming_opts: streaming_opts
    }
  end

  @spec run(t()) :: :ok
  def run(%__MODULE__{} = runner) do
    registry_entry = SwarmAi.running_execution_registry_entry_for_agent(runner.agent)

    try do
      result = SwarmAi.Executor.run(runner.agent, runner.streaming_opts)

      # Unregister BEFORE dispatch so running?/1 returns false first.
      Registry.unregister(runner.registry, registry_entry)
      send(runner.watcher, :completed)

      case result do
        {:ok, _, _} = ok ->
          dispatch_agent_event(runner.dispatcher, runner.agent, {:completed, ok}, runner.context)

        {:error, _, _} = err ->
          dispatch_agent_event(runner.dispatcher, runner.agent, {:failed, err}, runner.context)

        {:paused, {:pause_agent, tool_call_id, tool_name, timeout_ms} = reason} ->
          :telemetry.execute(
            [:swarm_ai, :runtime, :paused],
            %{count: 1},
            %{agent_id: SwarmAi.id!(runner.agent), reason: reason}
          )

          dispatch_agent_event(
            runner.dispatcher,
            runner.agent,
            {:paused, {:timeout, tool_call_id, tool_name, timeout_ms}},
            runner.context
          )
      end
    after
      # Safety net, idempotent if already unregistered above.
      Registry.unregister(runner.registry, registry_entry)
    end
  end

  # Wraps the execution's batch tool executor with per-tool supervised execution.
  # The inner executor returns [ToolExecution.t()] describing how to run each tool.
  # PE is the sole execution authority.
  defp wrap_executor_with_supervised_execution(tool_executor, task_supervisor) do
    build = Map.fetch!(tool_executor, :build)
    execution_mode = Map.fetch!(tool_executor, :execution_mode)

    fn tool_calls ->
      executions = build.(tool_calls)

      case run_tool_executions(executions, task_supervisor, execution_mode) do
        {:ok, results} -> results
        {:halt, _} = halt -> halt
      end
    end
  end

  defp run_tool_executions(executions, task_supervisor, :serial),
    do: SwarmAi.ParallelExecutor.run_serial(executions, task_supervisor)

  defp run_tool_executions(executions, task_supervisor, :parallel),
    do: SwarmAi.ParallelExecutor.run(executions, task_supervisor)

  defp build_streaming_opts(opts, nil, _agent, _context, _watcher), do: opts

  defp build_streaming_opts(opts, dispatcher, agent, context, watcher) do
    Keyword.merge(opts,
      on_chunk: fn chunk ->
        dispatch_agent_event(dispatcher, agent, {:chunk, chunk}, context)
      end,
      on_response: fn response ->
        send(watcher, {:snapshot, response})
        dispatch_agent_event(dispatcher, agent, {:response, response}, context)
      end,
      on_tool_call: fn tc ->
        dispatch_agent_event(dispatcher, agent, {:tool_call, tc}, context)
      end
    )
  end

  # Spawns a linked watcher process that observes the caller for unexpected
  # death. Waits for readiness so trap_exit is set before the task proceeds.
  defp spawn_death_watcher(dispatcher, agent, context) do
    caller = self()

    pid =
      spawn_link(fn ->
        Process.flag(:trap_exit, true)
        send(caller, {:watcher_ready, self()})
        watcher_loop(caller, dispatcher, agent, context, nil)
      end)

    receive do
      {:watcher_ready, ^pid} -> pid
    after
      5_000 -> raise "SwarmAi death watcher failed to start"
    end
  end

  defp watcher_loop(caller, dispatcher, agent, context, loop_snapshot) do
    receive do
      {:snapshot, response} ->
        watcher_loop(caller, dispatcher, agent, context, response)

      :completed ->
        :ok

      {:EXIT, ^caller, reason} ->
        case reason do
          :normal ->
            :ok

          :cancelled ->
            Logger.info("Execution cancelled for #{inspect(SwarmAi.id!(agent))}")
            dispatch_agent_event(dispatcher, agent, {:cancelled, %{loop: loop_snapshot}}, context)

          :shutdown ->
            Logger.info(
              "Execution terminated by supervisor for #{inspect(SwarmAi.id!(agent))}, reason: :shutdown"
            )

            dispatch_agent_event(
              dispatcher,
              agent,
              {:terminated, %{loop: loop_snapshot}},
              context
            )

          {:shutdown, _} = reason ->
            Logger.info(
              "Execution terminated by supervisor for #{inspect(SwarmAi.id!(agent))}, reason: #{inspect(reason)}"
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
              "Execution crashed for #{inspect(SwarmAi.id!(agent))}, reason: #{inspect(reason)}"
            )

            dispatch_agent_event(
              dispatcher,
              agent,
              {:crashed, %{reason: crash_reason, stacktrace: stacktrace, loop: loop_snapshot}},
              context
            )

            emit_telemetry(agent, caller, reason)
        end
    end
  end

  defp normalize_crash_reason({_exception, _stacktrace} = reason), do: reason
  defp normalize_crash_reason(reason), do: {reason, []}

  defp emit_telemetry(agent, pid, reason) do
    :telemetry.execute(
      [:swarm_ai, :runtime, :crash],
      %{count: 1},
      %{agent_id: SwarmAi.id!(agent), pid: pid, reason: reason}
    )
  end

  defp dispatch_agent_event(dispatcher, agent, event, context) do
    dispatch_event(dispatcher, SwarmAi.id!(agent), event, context)
  end

  defp dispatch_event(nil, _agent_id, _event, _context), do: :ok

  defp dispatch_event({mod, fun, args}, agent_id, event, context) do
    apply(mod, fun, args ++ [agent_id, event, context])
    :ok
  rescue
    e ->
      # Dispatch failures must not crash the watcher or block cleanup.
      Logger.error("SwarmAi event dispatch failed: #{Exception.message(e)}")
      {:error, e}
  end
end
