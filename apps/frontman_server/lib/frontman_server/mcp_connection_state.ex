defmodule FrontmanServer.MCPConnectionState do
  @moduledoc false

  use GenServer

  @timeout_ms 5_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @spec register(pid()) :: :ok
  def register(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:register, pid}, @timeout_ms)
  end

  @spec unregister(pid()) :: :ok
  def unregister(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:unregister, pid}, @timeout_ms)
  end

  @spec update_catalog(pid(), :pending | :ready | :failed, list()) :: :ok
  def update_catalog(pid, status, tools)
      when is_pid(pid) and status in [:pending, :ready, :failed] and is_list(tools) do
    GenServer.call(__MODULE__, {:update_catalog, pid, status, tools}, @timeout_ms)
  end

  @spec update_project_context(pid(), String.t(), :ready | :failed) :: :ok
  def update_project_context(pid, task_id, status)
      when is_pid(pid) and is_binary(task_id) and status in [:ready, :failed] do
    GenServer.call(__MODULE__, {:update_project_context, pid, task_id, status}, @timeout_ms)
  end

  @spec catalog(pid()) :: {:ok, :pending | :ready | :failed, list()} | :unavailable
  def catalog(pid) when is_pid(pid) do
    GenServer.call(__MODULE__, {:catalog, pid}, @timeout_ms)
  end

  @spec project_context(pid(), String.t()) :: {:ok, :ready | :failed | :pending} | :unavailable
  def project_context(pid, task_id) when is_pid(pid) and is_binary(task_id) do
    GenServer.call(__MODULE__, {:project_context, pid, task_id}, @timeout_ms)
  end

  @impl true
  def init(_options), do: {:ok, %{connections: %{}, monitors: %{}}}

  @impl true
  def handle_call({:register, pid}, _from, state) do
    {:reply, :ok, ensure_connection(state, pid)}
  end

  def handle_call({:unregister, pid}, _from, state) do
    {:reply, :ok, delete_connection(state, pid)}
  end

  def handle_call({:update_catalog, pid, status, tools}, _from, state) do
    state = ensure_connection(state, pid)
    connection = Map.fetch!(state.connections, pid)
    updated = %{connection | catalog: {status, tools}}
    {:reply, :ok, put_in(state.connections[pid], updated)}
  end

  def handle_call({:update_project_context, pid, task_id, status}, _from, state) do
    state = ensure_connection(state, pid)
    connection = Map.fetch!(state.connections, pid)
    updated = put_in(connection.project_contexts[task_id], status)
    {:reply, :ok, put_in(state.connections[pid], updated)}
  end

  def handle_call({:catalog, pid}, _from, state) do
    reply =
      case state.connections[pid] do
        %{catalog: {status, tools}} -> {:ok, status, tools}
        nil -> :unavailable
      end

    {:reply, reply, state}
  end

  def handle_call({:project_context, pid, task_id}, _from, state) do
    reply =
      case state.connections[pid] do
        %{project_contexts: contexts} -> {:ok, Map.get(contexts, task_id, :pending)}
        nil -> :unavailable
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_info({:DOWN, monitor, :process, pid, _reason}, state) do
    ^pid = Map.fetch!(state.monitors, monitor)
    {:noreply, delete_connection(state, pid)}
  end

  defp delete_connection(state, pid) do
    case Enum.find(state.monitors, fn {_monitor, monitored_pid} -> monitored_pid == pid end) do
      {monitor, ^pid} ->
        Process.demonitor(monitor, [:flush])

        %{
          state
          | connections: Map.delete(state.connections, pid),
            monitors: Map.delete(state.monitors, monitor)
        }

      nil ->
        state
    end
  end

  defp ensure_connection(state, pid) do
    case state.connections[pid] do
      nil ->
        monitor = Process.monitor(pid)
        connection = %{catalog: {:pending, []}, project_contexts: %{}}

        %{
          state
          | connections: Map.put(state.connections, pid, connection),
            monitors: Map.put(state.monitors, monitor, pid)
        }

      _connection ->
        state
    end
  end
end
