defmodule FrontmanServer.Tasks.Task do
  @moduledoc """
  Domain entity representing a conversational task.

  A task is an aggregate root that contains a series of interactions.
  Tasks are identified by task_id which also serves as the agent_id.
  """

  use TypedStruct

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.MCP

  typedstruct enforce: true do
    field :task_id, String.t()
    field :short_desc, String.t()
    field :interactions, list(Interaction.t()), default: []
    # MCP tools from client (structured, not LLM-formatted)
    field :mcp_tools, list(MCP.t()), default: []
    field :framework, String.t() | nil, default: nil
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
  Generates a short description from a task_id.

  Takes the first 8 characters of the task_id.
  """
  @spec short_description(String.t()) :: String.t()
  def short_description(task_id) do
    "Task #{String.slice(task_id, 0..7)}"
  end

  @doc """
  Sets the MCP tools for the task.

  MCP tools are stored as structured `MCP` struct.
  """
  @spec set_mcp_tools(t(), list(MCP.t())) :: t()
  def set_mcp_tools(%__MODULE__{} = task, mcp_tools) do
    %{task | mcp_tools: mcp_tools}
  end
end
