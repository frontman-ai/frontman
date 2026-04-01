defmodule SwarmAi.Runtime do
  @moduledoc """
  Supervised agent execution with lifecycle management.

  Provides process-level concerns that the pure SwarmAi execution loop
  doesn't handle: supervised spawning, duplicate prevention, crash monitoring,
  cancellation, and cleanup timing.

  ## Usage

      children = [
        {SwarmAi.Runtime,
          name: MyApp.AgentRuntime,
          event_dispatcher: {MyApp.SwarmDispatcher, :dispatch, []}},
      ]

  Then run agents:

      SwarmAi.Runtime.run(MyApp.AgentRuntime, task_id, agent, messages,
        tool_executor: &execute_tool/1
      )

  ## Event Dispatcher

  All execution events are dispatched via a `{mod, fun, args}` MFA tuple
  configured at startup. Events are dispatched as:

      apply(mod, fun, args ++ [key, event, metadata])

  The `metadata` map is the one passed via `opts[:metadata]` at `run/5` time,
  allowing callers to attach context (e.g. scope, API key info) that flows
  through every event — not just `:completed`/`:failed`.

  Events: `{:chunk, chunk}`, `{:response, response}`, `{:tool_call, tc}`,
  `{:completed, {:ok, result, loop_id}}`, `{:failed, {:error, reason, loop_id}}`,
  `{:crashed, %{reason, stacktrace, loop}}`, `{:cancelled, %{loop}}`,
  `{:terminated, %{loop}}`.

  Because the dispatcher is an MFA tuple (static config), it survives process
  restarts — no callbacks are lost.
  """

  alias __MODULE__.AgentTask
  alias __MODULE__.Handshake

  require Logger

  @doc """
  Returns a child spec for the Runtime supervision subtree.

  ## Options

  - `:name` - Required. Prefix for Registry and TaskSupervisor.
  - `:event_dispatcher` - Optional `{mod, fun, args}` MFA tuple for event dispatch.
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :name)

    %{
      id: {__MODULE__, name},
      start: {SwarmAi.Runtime.Supervisor, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc """
  Runs an agent with lifecycle management.

  Spawns a supervised task that registers the execution under `key`,
  monitors for crashes, calls `SwarmAi.run_streaming/3`, and dispatches
  events via the configured MFA dispatcher.

  ## Options

  - `:tool_executor` - Required. Batch function `([ToolCall.t()] -> [ToolResult.t()])`.
    The Runtime wraps it with parallel execution so each tool call runs concurrently.
  - `:metadata` - Arbitrary map attached to the loop for telemetry correlation.

  ## Returns

  - `{:ok, pid}` - Execution started
  - `{:error, :already_running}` - Duplicate execution for this key
  - `{:error, :registration_timeout}` - Child failed to ack within 5s
  """
  @spec run(atom(), term(), SwarmAi.Agent.t(), SwarmAi.message_input(), keyword()) ::
          {:ok, pid()} | {:error, :already_running | :registration_timeout}
  def run(runtime, key, agent, messages, opts \\ []) do
    registry = registry_name(runtime)

    case Registry.lookup(registry, {:running, key}) do
      [{_pid, _}] ->
        {:error, :already_running}

      [] ->
        task = %AgentTask{
          key: key,
          agent: agent,
          messages: messages,
          loop_config: opts,
          event_context: Keyword.get(opts, :metadata, %{})
        }

        handshake = %Handshake{caller: self(), ack_ref: make_ref()}
        spawn_and_await_registration(runtime, task, handshake)
    end
  end

  @doc """
  Returns true if an execution is running for the given key.
  """
  @spec running?(atom(), term()) :: boolean()
  def running?(runtime, key) do
    case Registry.lookup(registry_name(runtime), {:running, key}) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc """
  Cancels a running execution.

  The process is killed with `:cancelled` exit reason.
  A `:cancelled` event is dispatched (not `:crashed`).
  """
  @spec cancel(atom(), term()) :: :ok | {:error, :not_running}
  def cancel(runtime, key) do
    case Registry.lookup(registry_name(runtime), {:running, key}) do
      [{pid, _}] ->
        Logger.info("SwarmAi.Runtime: Cancelling execution for key #{inspect(key)}")
        Process.exit(pid, :cancelled)
        :ok

      [] ->
        {:error, :not_running}
    end
  end

  # --- Private ---

  defp spawn_and_await_registration(runtime, task, handshake) do
    registry = registry_name(runtime)
    task_sup = task_supervisor_name(runtime)
    registry_key = {:running, task.key}

    task_fn = fn ->
      case Registry.register(registry, registry_key, %{}) do
        {:ok, _} ->
          run_registered_task(runtime, task, handshake)

        {:error, {:already_registered, _}} ->
          send(handshake.caller, {handshake.ack_ref, :already_running})
          exit(:normal)
      end
    end

    case Task.Supervisor.start_child(task_sup, task_fn) do
      {:ok, pid} ->
        await_registration_ack(handshake.ack_ref, pid)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Wraps the caller's batch tool_executor with per-tool parallel execution.
  # Each tool call in a batch is run concurrently via Task.Supervisor.
  # Crashes in individual tool tasks are caught and converted to error ToolResults.
  defp wrap_executor_with_parallel(opts, task_supervisor) do
    case Keyword.fetch(opts, :tool_executor) do
      :error -> opts
      {:ok, executor} -> do_wrap_executor(opts, executor, task_supervisor)
    end
  end

  defp do_wrap_executor(opts, executor, task_supervisor) do
    parallel_executor = fn tool_calls ->
      task_supervisor
      |> Task.Supervisor.async_stream_nolink(
        tool_calls,
        fn tc ->
          [result] = executor.([tc])
          result
        end,
        max_concurrency: 10,
        ordered: true,
        timeout: :timer.minutes(30)
      )
      |> Enum.zip(tool_calls)
      |> Enum.map(&collect_tool_result/1)
    end

    Keyword.put(opts, :tool_executor, parallel_executor)
  end

  defp collect_tool_result({{:ok, result}, _tc}), do: result

  defp collect_tool_result({{:exit, reason}, tc}),
    do: SwarmAi.ToolResult.make(tc.id, "Tool execution crashed: #{inspect(reason)}", true)

  defp run_registered_task(runtime, task, handshake) do
    registry = registry_name(runtime)
    task_sup = task_supervisor_name(runtime)
    registry_key = {:running, task.key}
    dispatcher = event_dispatcher(runtime)

    watcher = spawn_death_watcher(dispatcher, task.key, task.event_context)

    streaming_opts =
      task.loop_config
      |> wrap_executor_with_parallel(task_sup)
      |> build_streaming_opts(dispatcher, task.key, task.event_context, watcher)

    send(handshake.caller, {handshake.ack_ref, :registered})

    try do
      result = SwarmAi.run_streaming(task.agent, task.messages, streaming_opts)

      # Unregister BEFORE dispatch so running?/2 returns false first
      Registry.unregister(registry, registry_key)
      send(watcher, :completed)

      case result do
        {:ok, _, _} = ok ->
          dispatch_event(dispatcher, task.key, {:completed, ok}, task.event_context)

        {:error, _, _} = err ->
          dispatch_event(dispatcher, task.key, {:failed, err}, task.event_context)
      end
    after
      # Safety net — idempotent if already unregistered above.
      # Do NOT send :completed here — on abnormal exits the watcher
      # must receive {:EXIT, ...} to dispatch crash/cancel events.
      Registry.unregister(registry, registry_key)
    end
  end

  defp build_streaming_opts(opts, nil, _key, _metadata, _watcher), do: opts

  defp build_streaming_opts(opts, dispatcher, key, metadata, watcher) do
    Keyword.merge(opts,
      on_chunk: fn chunk ->
        dispatch_event(dispatcher, key, {:chunk, chunk}, metadata)
      end,
      on_response: fn response ->
        send(watcher, {:snapshot, response})
        dispatch_event(dispatcher, key, {:response, response}, metadata)
      end,
      on_tool_call: fn tc ->
        dispatch_event(dispatcher, key, {:tool_call, tc}, metadata)
      end
    )
  end

  defp await_registration_ack(ack_ref, pid) do
    mon = Process.monitor(pid)

    receive do
      {^ack_ref, :registered} ->
        Process.demonitor(mon, [:flush])
        {:ok, pid}

      {^ack_ref, :already_running} ->
        Process.demonitor(mon, [:flush])
        {:error, :already_running}

      {:DOWN, ^mon, :process, ^pid, _reason} ->
        {:error, :already_running}
    after
      5_000 ->
        Process.demonitor(mon, [:flush])
        {:error, :registration_timeout}
    end
  end

  # Spawns a linked watcher process that observes the caller for unexpected
  # death (crash or cancellation). Uses a handshake to guarantee trap_exit
  # is set before the task proceeds — same race prevention as StreamCleanup.
  #
  # The watcher does NOT unregister from the Registry — only the owning
  # process (the task) can unregister its own keys. The task's `after` block
  # handles normal/exception cleanup; for external kills (e.g. :cancelled),
  # the Registry's built-in :DOWN monitor removes the entry automatically.
  defp spawn_death_watcher(dispatcher, key, metadata) do
    caller = self()
    callers = Process.get(:"$callers", [])

    pid =
      spawn_link(fn ->
        Process.put(:"$callers", [caller | callers])
        Process.flag(:trap_exit, true)
        send(caller, {:watcher_ready, self()})
        watcher_loop(caller, dispatcher, key, metadata, nil)
      end)

    receive do
      {:watcher_ready, ^pid} -> pid
    end
  end

  defp watcher_loop(caller, dispatcher, key, metadata, loop_snapshot) do
    receive do
      {:snapshot, response} ->
        watcher_loop(caller, dispatcher, key, metadata, response)

      :completed ->
        :ok

      {:EXIT, ^caller, reason} ->
        case reason do
          :normal ->
            :ok

          :cancelled ->
            Logger.info("Execution cancelled for #{inspect(key)}")

            dispatch_event(
              dispatcher,
              key,
              {:cancelled, %{loop: loop_snapshot}},
              metadata
            )

          :shutdown ->
            Logger.info(
              "Execution terminated by supervisor for #{inspect(key)}, reason: :shutdown"
            )

            dispatch_event(
              dispatcher,
              key,
              {:terminated, %{loop: loop_snapshot}},
              metadata
            )

          {:shutdown, _} = reason ->
            Logger.info(
              "Execution terminated by supervisor for #{inspect(key)}, reason: #{inspect(reason)}"
            )

            dispatch_event(
              dispatcher,
              key,
              {:terminated, %{loop: loop_snapshot}},
              metadata
            )

          reason ->
            {crash_reason, stacktrace} = normalize_crash_reason(reason)

            Logger.warning("Execution crashed for #{inspect(key)}, reason: #{inspect(reason)}")

            dispatch_event(
              dispatcher,
              key,
              {:crashed, %{reason: crash_reason, stacktrace: stacktrace, loop: loop_snapshot}},
              metadata
            )

            emit_telemetry(key, caller, reason)
        end
    end
  end

  defp normalize_crash_reason({_exception, _stacktrace} = reason), do: reason
  defp normalize_crash_reason(reason), do: {reason, []}

  defp emit_telemetry(key, pid, reason) do
    :telemetry.execute(
      [:swarm_ai, :runtime, :crash],
      %{count: 1},
      %{key: key, pid: pid, reason: reason}
    )
  end

  defp dispatch_event(nil, _key, _event, _metadata), do: :ok

  defp dispatch_event({mod, fun, args}, key, event, metadata) do
    apply(mod, fun, args ++ [key, event, metadata])
    :ok
  rescue
    e ->
      # Intentionally non-fatal: dispatch failures must not crash the
      # watcher or prevent cleanup of the running task.
      Logger.error("SwarmAi.Runtime event dispatch failed: #{Exception.message(e)}")
      {:error, e}
  end

  defp event_dispatcher(runtime) do
    :persistent_term.get({SwarmAi.Runtime, runtime, :event_dispatcher}, nil)
  end

  @doc false
  @spec registry_name(atom()) :: atom()
  def registry_name(runtime), do: :"#{runtime}.Registry"

  @doc false
  @spec task_supervisor_name(atom()) :: atom()
  def task_supervisor_name(runtime), do: :"#{runtime}.TaskSupervisor"
end
