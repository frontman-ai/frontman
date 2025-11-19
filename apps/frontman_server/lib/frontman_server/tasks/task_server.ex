defmodule FrontmanServer.Tasks.TaskServer do
  @moduledoc """
  GenServer managing a single task's runtime state and interaction history.

  Tasks store interactions as an append-only event log. Message chains are
  built as projections from this history when needed.
  """
  use GenServer
  require Logger

  alias FrontmanServer.Interaction

  defstruct [:task_id, interactions: []]

  @type t :: %__MODULE__{
          task_id: String.t(),
          interactions: list(Interaction.t())
        }

  # Client API

  @doc """
  Starts a new task server with the given task ID.
  """
  def start_link(task_id) do
    GenServer.start_link(__MODULE__, task_id, name: via(task_id))
  end

  @doc """
  Returns the via tuple for Registry lookup.
  """
  def via(task_id) do
    {:via, Registry, {FrontmanServer.TaskRegistry, task_id}}
  end

  @doc """
  Appends an interaction to the task's history.

  Broadcasts the interaction via PubSub to all subscribers.
  """
  def append_interaction(task_id, interaction) do
    GenServer.call(via(task_id), {:append_interaction, interaction})
  end

  @doc """
  Returns all interactions for the task.
  """
  def get_interactions(task_id) do
    GenServer.call(via(task_id), :get_interactions)
  end

  @doc """
  Returns the task state.
  """
  def get_state(task_id) do
    GenServer.call(via(task_id), :get_state)
  end

  # Server Callbacks

  @impl true
  def init(task_id) do
    Logger.info("Starting TaskServer for task: #{task_id}")

    state = %__MODULE__{
      task_id: task_id,
      interactions: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:append_interaction, interaction}, _from, state) do
    new_state = %{state | interactions: state.interactions ++ [interaction]}

    # Broadcast the new interaction to all subscribers
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      topic(state.task_id),
      {:interaction, interaction}
    )

    {:reply, {:ok, interaction}, new_state}
  end

  @impl true
  def handle_call(:get_interactions, _from, state) do
    {:reply, state.interactions, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Private Functions

  defp topic(task_id), do: "task:#{task_id}"
end
