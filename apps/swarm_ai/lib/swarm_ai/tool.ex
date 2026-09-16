defmodule SwarmAi.Tool do
  @moduledoc """
  Tool definition for LLM consumption.

  This is pure data describing a tool's interface for LLM consumption.
  Callers provide execution deadlines and error callbacks on execution descriptors,
  not on these model-facing declarations.
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:name, String.t())
    field(:description, String.t())
    field(:access, :read | :write | :read_write)
    field(:parameter_schema, map())
  end

  @doc """
  Creates a new tool definition.

  All four fields are required. Raises `ArgumentError` if any is missing
  or `KeyError` if an unknown key is provided.

  ## Example

      Tool.new(
        name: "question",
        description: "Ask the user a question",
        access: :write,
        parameter_schema: %{}
      )
  """
  @spec new(keyword()) :: t()
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end
end
