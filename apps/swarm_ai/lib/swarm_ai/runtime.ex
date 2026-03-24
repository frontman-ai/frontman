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
  `{:crashed, %{reason, stacktrace, loop}}`, `{:cancelled, %{loop}}`.

  Because the dispatcher is an MFA tuple (static config), it survives process
  restarts — no callbacks are lost.
  """

  require Logger

  @doc """
  Returns a child spec for the Runtime supervision subtree.

  ## Options

  - `:name` - Required. Prefix for Registry and TaskSupervisor.
  - `:event_dispatcher` - Optional `{mod, fun, args}` MFA tuple for event dispatch.
  """
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

  - `:tool_executor` - Required. Function to execute tool calls.
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
    task_sup = task_supervisor_name(runtime)
    dispatcher = event_dispatcher(runtime)

    registry_key = {:running, key}

    case Registry.lookup(registry, registry_key) do
      [{_pid, _}] ->
        {:error, :already_running}

      [] ->
        spawn_and_await_registration(
          task_sup,
          registry,
          registry_key,
          key,
          agent,
          messages,
          opts,
          dispatcher
        )
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

  defp spawn_and_await_registration(
         task_sup,
         registry,
         registry_key,
         key,
         agent,
         messages,
         opts,
         dispatcher
       ) do
    caller = self()
    ack_ref = make_ref()

    metadata = Keyword.get(opts, :metadata, %{})

    case Task.Supervisor.start_child(task_sup, fn ->
           case Registry.register(registry, registry_key, %{}) do
             {:ok, _} ->
               watcher =
                 spawn_death_watcher(dispatcher, key, metadata)

               streaming_opts =
                 build_streaming_opts(opts, dispatcher, key, metadata, watcher)

               send(caller, {ack_ref, :registered})

               try do
                 result = SwarmAi.run_streaming(agent, messages, streaming_opts)

                 # Unregister BEFORE dispatch so running?/2 returns false first
                 Registry.unregister(registry, registry_key)
                 send(watcher, :completed)

                 case result do
                   {:ok, _, _} = ok ->
                     dispatch_event(dispatcher, key, {:completed, ok}, metadata)

                   {:error, _, _} = err ->
                     dispatch_event(dispatcher, key, {:failed, err}, metadata)
                 end
               after
                 # Safety net — idempotent if already unregistered above.
                 # Do NOT send :completed here — on abnormal exits the watcher
                 # must receive {:EXIT, ...} to dispatch crash/cancel events.
                 Registry.unregister(registry, registry_key)
               end

             {:error, {:already_registered, _}} ->
               send(caller, {ack_ref, :already_running})
               exit(:normal)
           end
         end) do
      {:ok, pid} ->
        await_registration_ack(ack_ref, pid)

      {:error, reason} ->
        {:error, reason}
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
        cond do
          reason == :cancelled ->
            Logger.info("Execution cancelled", key: inspect(key))

            dispatch_event(
              dispatcher,
              key,
              {:cancelled, %{loop: loop_snapshot}},
              metadata
            )

          reason not in [:normal, :shutdown] and not match?({:shutdown, _}, reason) ->
            {crash_reason, stacktrace} = normalize_crash_reason(reason)

            Logger.warning("Execution crashed",
              key: inspect(key),
              reason: inspect(reason)
            )

            dispatch_event(
              dispatcher,
              key,
              {:crashed, %{reason: crash_reason, stacktrace: stacktrace, loop: loop_snapshot}},
              metadata
            )

            emit_telemetry(key, caller, reason)

          true ->
            :ok
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
  rescue
    e ->
      Logger.error("SwarmAi.Runtime event dispatch failed: #{Exception.message(e)}")
  end

  defp event_dispatcher(runtime) do
    :persistent_term.get({SwarmAi.Runtime, runtime, :event_dispatcher}, nil)
  end

  @doc false
  def registry_name(runtime), do: :"#{runtime}.Registry"

  @doc false
  def task_supervisor_name(runtime), do: :"#{runtime}.TaskSupervisor"
end
