defmodule FrontmanNotifier.Scheduler do
  @moduledoc """
  Periodic scheduler for notifier jobs.
  """

  use GenServer

  require Logger

  alias FrontmanNotifier.Config

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    send(self(), :run)
    {:ok, %{task_ref: nil, interval_ms: Config.check_interval_ms()}}
  end

  @impl GenServer
  def handle_info(:run, %{task_ref: nil} = state) do
    task =
      Task.Supervisor.async_nolink(FrontmanNotifier.TaskSupervisor, &FrontmanNotifier.run_once/0)

    {:noreply, %{state | task_ref: task.ref}}
  end

  def handle_info(:run, state) do
    Logger.warning("Notifier run skipped because a previous run is still active")
    schedule_next(state.interval_ms)
    {:noreply, state}
  end

  def handle_info({ref, result}, %{task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])
    Logger.info("Notifier run finished: #{inspect(result)}")
    schedule_next(state.interval_ms)
    {:noreply, %{state | task_ref: nil}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{task_ref: ref} = state) do
    Logger.error("Notifier run crashed: #{inspect(reason)}")
    schedule_next(state.interval_ms)
    {:noreply, %{state | task_ref: nil}}
  end

  defp schedule_next(interval_ms) do
    Process.send_after(self(), :run, interval_ms)
  end
end
