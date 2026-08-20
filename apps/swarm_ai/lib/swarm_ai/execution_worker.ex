defmodule SwarmAi.ExecutionWorker do
  @moduledoc false

  use GenServer, restart: :temporary
  use TypedStruct

  require Logger

  typedstruct enforce: true do
    field(:runtime, atom())
    field(:loop, SwarmAi.Loop.t())
    field(:worker_pid, pid(), enforce: false)
    field(:worker_monitor, reference(), enforce: false)
    field(:final_status, SwarmAi.Loop.status(), enforce: false)
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
    Process.flag(:trap_exit, true)
    lifecycle_pid = self()
    callers = [lifecycle_pid | Process.get(:"$callers", [])]
    worker_loop = dispatch_through_lifecycle(loop, lifecycle_pid)

    {worker_pid, worker_monitor} =
      :erlang.spawn_opt(
        fn ->
          Process.put(:"$callers", callers)

          receive do
            :run ->
              final_loop =
                SwarmAi.Executor.run(worker_loop, SwarmAi.task_supervisor_name(runtime))

              send(lifecycle_pid, {:execution_finished, final_loop.status})
          end
        end,
        [:link, :monitor]
      )

    state = %__MODULE__{
      runtime: runtime,
      loop: loop,
      worker_pid: worker_pid,
      worker_monitor: worker_monitor
    }

    {:ok, state, {:continue, :run}}
  end

  @impl true
  def handle_continue(:run, %__MODULE__{worker_pid: worker_pid} = state) do
    send(worker_pid, :run)
    {:noreply, state}
  end

  @impl true
  def handle_call({:dispatch_event, event}, _from, %__MODULE__{} = state) do
    {:reply, state.loop.dispatch_event.(event), state}
  end

  @impl true
  def handle_info(
        {:execution_finished, status},
        %__MODULE__{final_status: nil} = state
      ) do
    {:noreply, %{state | final_status: status}}
  end

  def handle_info(
        {:DOWN, worker_monitor, :process, worker_pid, reason},
        %__MODULE__{worker_pid: worker_pid, worker_monitor: worker_monitor} = state
      ) do
    dispatch_terminal_event(state.loop, reason, state.final_status)
    Registry.unregister(SwarmAi.registry_name(state.runtime), state.loop.task_id)
    {:stop, lifecycle_stop_reason(reason), %{state | worker_pid: nil, worker_monitor: nil}}
  end

  def handle_info(
        {:EXIT, worker_pid, _reason},
        %__MODULE__{worker_pid: worker_pid} = state
      ) do
    {:noreply, state}
  end

  def handle_info({:EXIT, _linked_pid, reason}, %__MODULE__{} = state) do
    {:stop, reason, state}
  end

  def handle_info(:cancel_execution, %__MODULE__{worker_pid: worker_pid} = state)
      when is_pid(worker_pid) do
    Process.exit(worker_pid, :cancelled)
    {:noreply, state}
  end

  def handle_info(:cancel_execution, %__MODULE__{} = state), do: {:noreply, state}

  @impl true
  def terminate(reason, %__MODULE__{worker_pid: worker_pid} = state) when is_pid(worker_pid) do
    Process.exit(worker_pid, :shutdown)

    case reason do
      :normal ->
        :ok

      :cancelled ->
        :ok

      :killed ->
        dispatch_terminal_event(state.loop, :killed, nil)

      {:shutdown, shutdown_reason} ->
        dispatch_terminal_event(state.loop, {:shutdown, shutdown_reason}, nil)

      _reason ->
        dispatch_terminal_event(state.loop, :shutdown, nil)
    end
  end

  def terminate(_reason, %__MODULE__{}), do: :ok

  defp dispatch_through_lifecycle(%SwarmAi.Loop{} = loop, lifecycle_pid) do
    %{loop | dispatch_event: &GenServer.call(lifecycle_pid, {:dispatch_event, &1}, 30_000)}
  end

  defp dispatch_terminal_event(%SwarmAi.Loop{} = loop, :normal, status) do
    loop.dispatch_event.(status)
  end

  defp dispatch_terminal_event(%SwarmAi.Loop{} = loop, :cancelled, _status) do
    Logger.info("Execution cancelled for #{loop.task_id}")
    loop.dispatch_event.({:cancelled, nil})
  end

  defp dispatch_terminal_event(%SwarmAi.Loop{} = loop, :shutdown, _status) do
    Logger.info("Execution terminated by supervisor for #{loop.task_id}, reason: :shutdown")
    loop.dispatch_event.({:terminated, nil})
  end

  defp dispatch_terminal_event(%SwarmAi.Loop{} = loop, :killed, _status) do
    Logger.info("Execution terminated by supervisor for #{loop.task_id}, reason: :killed")
    loop.dispatch_event.({:terminated, :killed})
  end

  defp dispatch_terminal_event(%SwarmAi.Loop{} = loop, {:shutdown, reason}, _status) do
    Logger.info(fn ->
      "Execution terminated by supervisor for #{loop.task_id}, reason: #{inspect(reason)}"
    end)

    loop.dispatch_event.({:terminated, reason})
  end

  defp dispatch_terminal_event(%SwarmAi.Loop{} = loop, reason, _status) do
    Logger.warning(fn ->
      "Execution crashed for #{loop.task_id}, reason: #{inspect(reason)}"
    end)

    loop.dispatch_event.({:crashed, %{message: Exception.format_exit(reason)}})
  end

  defp lifecycle_stop_reason(:normal), do: :normal
  defp lifecycle_stop_reason(:cancelled), do: :normal
  defp lifecycle_stop_reason(reason), do: reason
end
