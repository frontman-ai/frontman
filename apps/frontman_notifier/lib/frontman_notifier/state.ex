defmodule FrontmanNotifier.State do
  @moduledoc """
  Durable state for notification de-duplication.
  """

  use GenServer

  alias FrontmanNotifier.Config

  @table :frontman_notifier_state

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    id = Keyword.get(opts, :name, __MODULE__)

    %{
      id: id,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end

  @impl GenServer
  def init(opts) do
    state_dir = Keyword.get(opts, :state_dir, Config.state_dir())
    table = Keyword.get(opts, :table, @table)
    File.mkdir_p!(state_dir)

    case :dets.open_file(table, file: state_path(state_dir), type: :set, repair: true) do
      {:ok, ^table} -> {:ok, %{table: table}}
      {:error, reason} -> {:stop, reason}
    end
  end

  @spec seen?(atom(), String.t(), GenServer.server()) :: boolean()
  def seen?(namespace, id, server \\ __MODULE__) when is_atom(namespace) and is_binary(id) do
    GenServer.call(server, {:seen?, {namespace, id}})
  end

  @spec mark_seen(atom(), String.t(), GenServer.server()) :: :ok
  def mark_seen(namespace, id, server \\ __MODULE__) when is_atom(namespace) and is_binary(id) do
    GenServer.call(server, {:mark_seen, {namespace, id}})
  end

  @spec initialized?(atom(), GenServer.server()) :: boolean()
  def initialized?(scope, server \\ __MODULE__) when is_atom(scope) do
    GenServer.call(server, {:seen?, {:initialized, Atom.to_string(scope)}})
  end

  @spec set_initialized(atom(), GenServer.server()) :: :ok
  def set_initialized(scope, server \\ __MODULE__) when is_atom(scope) do
    GenServer.call(server, {:mark_seen, {:initialized, Atom.to_string(scope)}})
  end

  @spec keys(atom(), GenServer.server()) :: list(String.t())
  def keys(namespace, server \\ __MODULE__) when is_atom(namespace) do
    GenServer.call(server, {:keys, namespace})
  end

  @impl GenServer
  def handle_call({:seen?, key}, _from, state) do
    case :dets.lookup(state.table, key) do
      [] -> {:reply, false, state}
      [_entry] -> {:reply, true, state}
    end
  end

  def handle_call({:mark_seen, key}, _from, state) do
    :ok = :dets.insert(state.table, {key, DateTime.utc_now(:second)})
    :ok = :dets.sync(state.table)
    {:reply, :ok, state}
  end

  def handle_call({:keys, namespace}, _from, state) do
    keys =
      state.table
      |> :dets.match({{namespace, :"$1"}, :_})
      |> Enum.map(fn [id] -> id end)
      |> Enum.sort()

    {:reply, keys, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    :dets.close(state.table)
    :ok
  end

  defp state_path(state_dir) do
    state_dir |> Path.join("notifier_state.dets") |> String.to_charlist()
  end
end
