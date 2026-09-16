defmodule SwarmAi.Runtime do
  @moduledoc false

  use GenServer

  require Logger

  @type state :: %{
          runtime: atom(),
          monitors: %{reference() => {String.t(), SwarmAi.Loop.t()}}
        }

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    runtime = Keyword.fetch!(opts, :runtime)
    GenServer.start_link(__MODULE__, runtime, name: runtime)
  end

  @doc false
  @spec run(atom(), String.t(), SwarmAi.Loop.t()) ::
          {:ok, pid()} | {:error, :already_running | {:start_failed, term()}}
  def run(runtime, key, %SwarmAi.Loop{} = loop) when is_atom(runtime) and is_binary(key) do
    with :ok <- await_finishing_execution(runtime, key) do
      case GenServer.call(runtime, {:run, key, loop}, 5_000) do
        {:error, {:start_failed, {:exit, reason}}} -> exit(reason)
        result -> result
      end
    end
  end

  @doc false
  @spec execution_finished(atom(), String.t()) :: :ok
  def execution_finished(runtime, key) when is_atom(runtime) and is_binary(key) do
    GenServer.call(runtime, {:execution_finished, key}, 5_000)
  catch
    :exit, _reason -> :ok
  end

  @doc false
  @spec running?(atom(), String.t()) :: boolean()
  def running?(runtime, key) when is_atom(runtime) and is_binary(key),
    do: SwarmAi.Runtime.Registry.lookup(runtime, key) != []

  @doc false
  @spec active_count(atom()) :: non_neg_integer()
  def active_count(runtime) when is_atom(runtime) do
    GenServer.call(runtime, :active_count, 5_000)
  end

  @doc false
  @spec cancel(atom(), String.t()) :: :ok | {:error, :not_running}
  def cancel(runtime, key) when is_atom(runtime) and is_binary(key) do
    case SwarmAi.Runtime.Registry.lookup(runtime, key) do
      [{_pid, :finishing}] ->
        :ok

      [{pid, _}] ->
        Logger.info("Cancelling execution for #{inspect(key)}")
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
    Process.flag(:trap_exit, true)
    {:ok, %{runtime: runtime, monitors: %{}}}
  end

  @impl true
  def handle_call({:run, key, %SwarmAi.Loop{} = loop}, _from, %{runtime: runtime} = state) do
    case start_execution(runtime, key, loop) do
      {:ok, pid, ref} ->
        {:reply, {:ok, pid}, put_in(state.monitors[ref], {key, loop})}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:execution_finished, key}, _from, state) do
    monitors =
      state.monitors
      |> Enum.reject(fn {_ref, {registered_key, _loop}} -> registered_key == key end)
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

      {{_key, %SwarmAi.Loop{} = loop}, monitors} ->
        SwarmAi.TerminalEvent.emit(loop, reason)
        {:noreply, %{state | monitors: monitors}}
    end
  end

  @impl true
  def terminate(reason, state) do
    Enum.each(state.monitors, fn {_ref, {_key, loop}} ->
      SwarmAi.TerminalEvent.emit(loop, reason)
    end)
  end

  defp await_finishing_execution(runtime, key) do
    case SwarmAi.Runtime.Registry.lookup(runtime, key) do
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

  defp start_execution(runtime, key, %SwarmAi.Loop{} = loop) do
    case DynamicSupervisor.start_child(
           execution_supervisor_name(runtime),
           {SwarmAi.ExecutionWorker, {runtime, key, loop}}
         ) do
      {:ok, pid} -> {:ok, pid, Process.monitor(pid)}
      {:error, {:already_started, _pid}} -> {:error, :already_running}
      {:error, reason} -> {:error, {:start_failed, reason}}
    end
  catch
    :exit, reason -> {:error, {:start_failed, {:exit, reason}}}
  end
end
