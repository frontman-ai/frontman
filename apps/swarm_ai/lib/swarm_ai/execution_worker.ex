defmodule SwarmAi.ExecutionWorker do
  @moduledoc false

  use GenServer, restart: :temporary
  use TypedStruct

  require Logger

  typedstruct enforce: true do
    field(:runtime, atom())
    field(:loop, SwarmAi.Loop.t())
  end

  @spec start_link({atom(), SwarmAi.Loop.t()}) :: GenServer.on_start()
  def start_link({runtime, %SwarmAi.Loop{task_id: task_id} = loop}) do
    registry = SwarmAi.registry_name(runtime)

    name =
      {:via, Registry, {registry, task_id}}

    GenServer.start_link(__MODULE__, {runtime, loop}, name: name)
  end

  @impl true
  def init({runtime, %SwarmAi.Loop{} = loop}) do
    spawn_death_watcher(loop)

    state = %__MODULE__{
      runtime: runtime,
      loop: loop
    }

    {:ok, state, {:continue, :run}}
  end

  @impl true
  def handle_continue(:run, %__MODULE__{loop: loop, runtime: runtime} = state) do
    registry = SwarmAi.registry_name(runtime)
    task_supervisor = SwarmAi.task_supervisor_name(runtime)

    try do
      final_loop = SwarmAi.Executor.run(loop, task_supervisor)
      final_loop.dispatch_event.(final_loop.status)
    after
      unregister(registry, loop)
    end

    {:stop, :normal, state}
  end

  defp unregister(registry, %SwarmAi.Loop{task_id: task_id}) do
    Registry.unregister(registry, task_id)
  catch
    :exit, {:noproc, _} -> :ok
    :exit, :noproc -> :ok
  end

  defp spawn_death_watcher(%SwarmAi.Loop{} = loop) do
    worker_pid = self()

    pid =
      spawn(fn ->
        try do
          monitor_ref = Process.monitor(worker_pid)
          send(worker_pid, {:watcher_ready, self()})
          watcher_loop(monitor_ref, worker_pid, loop)
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

  defp watcher_loop(monitor_ref, worker_pid, %SwarmAi.Loop{} = loop) do
    receive do
      {:DOWN, ^monitor_ref, :process, ^worker_pid, :normal} ->
        :ok

      {:DOWN, ^monitor_ref, :process, ^worker_pid, :cancelled} ->
        Logger.info("Execution cancelled for #{loop.task_id}")
        event = {:cancelled, nil}
        loop.dispatch_event.(event)

      {:DOWN, ^monitor_ref, :process, ^worker_pid, :shutdown} ->
        Logger.info("Execution terminated by supervisor for #{loop.task_id}, reason: :shutdown")
        event = {:terminated, nil}
        loop.dispatch_event.(event)

      {:DOWN, ^monitor_ref, :process, ^worker_pid, :killed} ->
        Logger.info("Execution terminated by supervisor for #{loop.task_id}, reason: :killed")
        event = {:terminated, :killed}
        loop.dispatch_event.(event)

      {:DOWN, ^monitor_ref, :process, ^worker_pid, {:shutdown, reason}} ->
        Logger.info(fn ->
          "Execution terminated by supervisor for #{loop.task_id}, reason: #{inspect(reason)}"
        end)

        event = {:terminated, reason}
        loop.dispatch_event.(event)

      {:DOWN, ^monitor_ref, :process, ^worker_pid, reason} ->
        message = Exception.format_exit(reason)

        Logger.warning(fn ->
          "Execution crashed for #{loop.task_id}, reason: #{inspect(reason)}"
        end)

        event = {:crashed, %{message: message}}
        loop.dispatch_event.(event)

      _other ->
        # Draining unrelated messages
        watcher_loop(monitor_ref, worker_pid, loop)
    end
  end
end
