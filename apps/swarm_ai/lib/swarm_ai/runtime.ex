defmodule SwarmAi.Runtime do
  @moduledoc false

  use GenServer

  require Logger

  @type state :: %{
          runtime: atom(),
          monitors: %{reference() => SwarmAi.Loop.t()}
        }

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    runtime = Keyword.fetch!(opts, :runtime)
    GenServer.start_link(__MODULE__, runtime, name: runtime)
  end

  @doc false
  @spec run(atom(), SwarmAi.Loop.t()) ::
          {:ok, pid()} | {:error, :already_running | {:start_failed, term()}}
  def run(runtime, %SwarmAi.Loop{} = loop) when is_atom(runtime) do
    with :ok <- await_finishing_execution(runtime, loop.task_id) do
      case GenServer.call(runtime, {:run, loop}, 5_000) do
        {:error, {:start_failed, {:exit, reason}}} -> exit(reason)
        result -> result
      end
    end
  end

  @doc false
  @spec execution_finished(atom(), String.t()) :: :ok
  def execution_finished(runtime, task_id) when is_atom(runtime) and is_binary(task_id) do
    GenServer.call(runtime, {:execution_finished, task_id}, 5_000)
  catch
    :exit, _reason -> :ok
  end

  @doc false
  @spec running?(atom(), String.t()) :: boolean()
  def running?(runtime, task_id) when is_atom(runtime) and is_binary(task_id),
    do: SwarmAi.Runtime.Registry.lookup(runtime, task_id) != []

  @doc false
  @spec active_count(atom()) :: non_neg_integer()
  def active_count(runtime) when is_atom(runtime) do
    GenServer.call(runtime, :active_count, 5_000)
  end

  @doc false
  @spec cancel(atom(), String.t()) :: :ok | {:error, :not_running}
  def cancel(runtime, task_id) when is_atom(runtime) and is_binary(task_id) do
    case SwarmAi.Runtime.Registry.lookup(runtime, task_id) do
      [{pid, _}] ->
        Logger.info("Cancelling execution for #{inspect(task_id)}")
        Process.exit(pid, :cancelled)
        :ok

      [] ->
        {:error, :not_running}
    end
  end

  @doc false
  @spec task_supervisor_name(atom()) :: atom()
  def task_supervisor_name(runtime), do: :"#{runtime}.TaskSupervisor"

  @doc false
  @spec execution_supervisor_name(atom()) :: atom()
  def execution_supervisor_name(runtime), do: :"#{runtime}.ExecutionSupervisor"

  @impl true
  @spec init(atom()) :: {:ok, state()}
  def init(runtime) when is_atom(runtime) do
    {:ok, %{runtime: runtime, monitors: %{}}}
  end

  @impl true
  def handle_call({:run, %SwarmAi.Loop{} = loop}, _from, %{runtime: runtime} = state) do
    case start_execution(runtime, loop) do
      {:ok, pid, ref} ->
        {:reply, {:ok, pid}, put_in(state.monitors[ref], loop)}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:execution_finished, task_id}, _from, state) do
    monitors =
      state.monitors
      |> Enum.reject(fn {_ref, loop} -> loop.task_id == task_id end)
      |> Map.new()

    {:reply, :ok, %{state | monitors: monitors}}
  end

  @impl true
  def handle_call(:active_count, _from, state) do
    {:reply, map_size(state.monitors), state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case Map.pop(state.monitors, ref) do
      {nil, monitors} ->
        {:noreply, %{state | monitors: monitors}}

      {%SwarmAi.Loop{} = loop, monitors} ->
        SwarmAi.TerminalEvent.emit(loop, reason)
        {:noreply, %{state | monitors: monitors}}
    end
  end

  defp await_finishing_execution(runtime, task_id) do
    case SwarmAi.Runtime.Registry.lookup(runtime, task_id) do
      [{pid, :finishing}] ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        after
          5_000 ->
            Process.demonitor(ref, [:flush])
            {:error, {:start_failed, :finishing_timeout}}
        end

      [{_pid, _running}] ->
        :ok

      [] ->
        :ok
    end
  end

  defp start_execution(runtime, %SwarmAi.Loop{} = loop) do
    case DynamicSupervisor.start_child(
           execution_supervisor_name(runtime),
           {SwarmAi.ExecutionWorker, {runtime, loop}}
         ) do
      {:ok, pid} -> {:ok, pid, Process.monitor(pid)}
      {:error, {:already_started, _pid}} -> {:error, :already_running}
      {:error, reason} -> {:error, {:start_failed, reason}}
    end
  catch
    :exit, reason -> {:error, {:start_failed, {:exit, reason}}}
  end
end
