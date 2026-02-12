defmodule FrontmanServer.Tasks.Task do
  @moduledoc """
  Domain entity representing a conversational task.

  A task is an aggregate root that contains a series of interactions.
  Tasks are identified by task_id which also serves as the agent_id.
  """

  use TypedStruct

  alias FrontmanServer.Tasks.Interaction

  typedstruct enforce: true do
    field(:task_id, String.t())
    field(:short_desc, String.t())
    field(:interactions, list(Interaction.t()), default: [])
    field(:framework, String.t() | nil, default: nil)
  end

  @doc """
  Creates a new task.

  Returns a Task struct ready to be persisted.
  """
  @spec new(String.t(), String.t() | nil) :: t()
  def new(task_id, framework \\ nil) do
    %__MODULE__{
      task_id: task_id,
      short_desc: short_description(task_id),
      interactions: [],
      framework: framework
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
  Returns the default short description for a new task.

  Titles are later generated asynchronously via `TitleGenerator`
  after the first user message.
  """
  @spec short_description(String.t()) :: String.t()
  def short_description(_task_id) do
    "New Task"
  end
end
