defmodule SwarmAi.Runtime do
  @moduledoc """
  Supervised agent execution with lifecycle management.

  Provides process-level concerns that the pure SwarmAi execution loop
  doesn't handle: supervised spawning, duplicate prevention, crash monitoring,
  cancellation, and cleanup timing.

  ## Usage

  Add a Runtime to your supervision tree:

      children = [
        {SwarmAi.Runtime, name: MyApp.AgentRuntime},
        ...
      ]

  Then run agents with lifecycle callbacks:

      SwarmAi.Runtime.run(MyApp.AgentRuntime, task_id, agent, messages,
        tool_executor: &execute_tool/1,
        on_chunk: fn chunk -> IO.write(chunk.text || "") end,
        on_complete: fn {:ok, result, loop_id} -> Logger.info("Done") end,
        on_error: fn {:error, reason, loop_id} -> Logger.error(inspect(reason)) end,
        on_crash: fn {reason, stacktrace} -> Logger.error("Crashed") end,
        on_cancelled: fn -> Logger.info("Cancelled") end
      )

  ## Lifecycle Callbacks

  These are invoked by the Runtime after the execution process completes:

  - `on_complete` - Called with `{:ok, result, loop_id}` after successful execution
  - `on_error` - Called with `{:error, reason, loop_id}` after failed execution
  - `on_crash` - Called with `{reason, stacktrace}` if the execution process crashes
  - `on_cancelled` - Called with no args if the execution is cancelled

  The execution key is unregistered BEFORE any callback fires, so `running?/2`
  returns `false` before completion events propagate.
  """

  require Logger

  alias SwarmAi.Runtime.ExecutionMonitor

  @doc """
  Returns a child spec for the Runtime supervision subtree.

  ## Options

  - `:name` - Required. Used as the supervisor name and prefix for
    Registry, TaskSupervisor, and ExecutionMonitor names.
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

  Spawns a supervised task that:
  1. Registers the execution under `key` (prevents duplicates)
  2. Monitors for crashes via ExecutionMonitor
  3. Calls `SwarmAi.run_streaming/3` with the provided opts
  4. Unregisters the key before invoking completion callbacks
  5. Emits telemetry events for the lifecycle

  ## Options

  All options from `SwarmAi.run_streaming/3`, plus:
  - `:on_complete` - Called with `{:ok, result, loop_id}` after successful execution
  - `:on_error` - Called with `{:error, reason, loop_id}` after failed execution
  - `:on_crash` - Called with `{reason, stacktrace}` if the execution process crashes
  - `:on_cancelled` - Called with no args if the execution is cancelled
  - `:metadata` - Map of metadata passed to `SwarmAi.run_streaming/3`

  ## Returns

  - `{:ok, pid}` - Execution started (process is alive and registered)
  - `{:error, :already_running}` - An execution is already running for this key
  - `{:error, :registration_timeout}` - Child process failed to ack within 5s (pathological)
  """
  @spec run(atom(), term(), SwarmAi.Agent.t(), SwarmAi.message_input(), keyword()) ::
          {:ok, pid()} | {:error, :already_running | :registration_timeout}
  def run(runtime, key, agent, messages, opts \\ []) do
    registry = registry_name(runtime)
    task_sup = task_supervisor_name(runtime)
    monitor = monitor_name(runtime)

    registry_key = {:running, key}

    # Quick check: reject obvious duplicates before spawning.
    # There's still a small race between this check and registration inside the task,
    # which is handled by the in-process Registry.register check.
    case Registry.lookup(registry, registry_key) do
      [{_pid, _}] ->
        {:error, :already_running}

      [] ->
        spawn_and_await_registration(
          task_sup,
          registry,
          registry_key,
          monitor,
          key,
          agent,
          messages,
          opts
        )
    end
  end

  @doc """
  Returns true if an execution is running for the given key.
  """
  @spec running?(atom(), term()) :: boolean()
  def running?(runtime, key) do
    registry = registry_name(runtime)

    case Registry.lookup(registry, {:running, key}) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @doc """
  Cancels a running execution.

  The process is killed with `:cancelled` exit reason.
  The `on_cancelled` callback is invoked (not `on_error`).

  Returns `:ok` if the agent was cancelled, `{:error, :not_running}` if
  no agent is running for the given key.
  """
  @spec cancel(atom(), term()) :: :ok | {:error, :not_running}
  def cancel(runtime, key) do
    registry = registry_name(runtime)

    case Registry.lookup(registry, {:running, key}) do
      [{pid, _}] ->
        Logger.info("SwarmAi.Runtime: Cancelling execution for key #{inspect(key)}")
        Process.exit(pid, :cancelled)
        :ok

      [] ->
        {:error, :not_running}
    end
  end

  # --- Private ---

  # Spawns the execution child and waits for it to confirm registration.
  # Returns {:ok, pid} only when the child is alive and registered,
  # or {:error, :already_running} if another process won the race.
  defp spawn_and_await_registration(
         task_sup,
         registry,
         registry_key,
         monitor,
         key,
         agent,
         messages,
         opts
       ) do
    on_complete = Keyword.get(opts, :on_complete, fn _ -> :ok end)
    on_error = Keyword.get(opts, :on_error, fn _ -> :ok end)

    streaming_opts =
      opts
      |> Keyword.drop([:on_complete, :on_error, :on_crash, :on_cancelled])

    caller = self()
    ack_ref = make_ref()

    case Task.Supervisor.start_child(task_sup, fn ->
           # Register: prevents duplicates at the process level.
           # Ack the caller so it knows whether we actually started.
           case Registry.register(registry, registry_key, %{}) do
             {:ok, _} ->
               send(caller, {ack_ref, :registered})

             {:error, {:already_registered, _}} ->
               send(caller, {ack_ref, :already_running})
               exit(:normal)
           end

           ExecutionMonitor.watch(monitor, key,
             on_crash: Keyword.get(opts, :on_crash, fn _ -> :ok end),
             on_cancelled: Keyword.get(opts, :on_cancelled, fn -> :ok end)
           )

           try do
             execute(
               agent,
               messages,
               streaming_opts,
               registry,
               registry_key,
               on_complete,
               on_error
             )
           after
             # Safety net — idempotent if already unregistered in execute
             Registry.unregister(registry, registry_key)
           end
         end) do
      {:ok, pid} ->
        await_registration_ack(ack_ref, pid)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Blocks until the spawned child confirms registration or fails.
  # Monitor ensures we don't hang if the child crashes before acking.
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
        # Child died before acking — most likely lost the registration race
        # and exited before the ack message was delivered, or crashed during
        # startup. Either way, no execution is running for this key.
        {:error, :already_running}
    after
      5_000 ->
        Process.demonitor(mon, [:flush])
        {:error, :registration_timeout}
    end
  end

  defp execute(agent, messages, opts, registry, registry_key, on_complete, on_error) do
    result = SwarmAi.run_streaming(agent, messages, opts)

    # Unregister BEFORE callback so running?/2 returns false before
    # completion events propagate
    Registry.unregister(registry, registry_key)

    case result do
      {:ok, _result, _loop_id} = ok ->
        on_complete.(ok)

      {:error, _reason, _loop_id} = err ->
        on_error.(err)
    end

    result
  end

  @doc false
  def registry_name(runtime), do: :"#{runtime}.Registry"

  @doc false
  def task_supervisor_name(runtime), do: :"#{runtime}.TaskSupervisor"

  @doc false
  def monitor_name(runtime), do: :"#{runtime}.ExecutionMonitor"
end
