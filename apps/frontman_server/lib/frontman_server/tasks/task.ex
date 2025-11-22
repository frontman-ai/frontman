defmodule FrontmanServer.Tasks.Task do
  @moduledoc """
  Domain entity representing a conversational task.

  A task is an aggregate root that contains a series of interactions.
  Tasks are identified by task_id which also serves as the agent_id.
  """

  use TypedStruct

  alias FrontmanServer.Tasks.Interaction

  typedstruct enforce: true do
    field :task_id, String.t()
    field :short_desc, String.t()
    field :session_id, String.t() | nil, enforce: false
    field :interactions, list(Interaction.t()), default: []
    field :metadata, map(), default: %{}, enforce: false
  end

  @doc """
  Creates a new task.

  Returns a Task struct ready to be persisted.
  """
  @spec new(String.t(), map()) :: t()
  def new(task_id, metadata \\ %{}) do
    %__MODULE__{
      task_id: task_id,
      short_desc: short_description(task_id),
      session_id: Map.get(metadata, :session_id),
      interactions: [],
      metadata: metadata
    }
  end

  @doc """
  Appends an interaction to the task's history.

  Returns the updated task.
  """
  @spec append_interaction(t(), Interaction.t()) :: t()
  def append_interaction(%__MODULE__{} = task, interaction) do
    %{task | interactions: task.interactions ++ [interaction]}
  end

  @doc """
  Generates a short description from a task_id.

  Takes the first 8 characters of the task_id.
  """
  @spec short_description(String.t()) :: String.t()
  def short_description(task_id) do
    "Task #{String.slice(task_id, 0..7)}"
  end
end
