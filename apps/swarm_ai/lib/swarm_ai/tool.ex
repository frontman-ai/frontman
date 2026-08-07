defmodule SwarmAi.Tool do
  use TypedStruct

  typedstruct enforce: true do
    field(:name, String.t())
    field(:description, String.t())
    field(:access, :read | :write | :read_write)
    field(:parameter_schema, map())
    field(:timeout_ms, pos_integer())
    field(:on_timeout, :error | :pause_agent)
  end

  @spec new(keyword()) :: t()
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end
end
