defmodule SwarmAi.Tool do
  @moduledoc """
  Tool definition for LLM consumption.

  This is pure data describing a tool's interface. Swarm doesn't execute tools -
  it yields ToolCalls for the caller to execute via the tool_executor function.
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:name, String.t())
    field(:description, String.t())
    field(:parameter_schema, map())
  end

  @doc """
  Creates a new tool definition.
  """
  @spec new(String.t(), String.t(), map()) :: t()
  def new(name, description, parameter_schema) do
    %__MODULE__{
      name: name,
      description: description,
      parameter_schema: parameter_schema
    }
  end
end
