defmodule SwarmAi.Tool do
  @moduledoc """
  Tool definition for LLM consumption.

  This is pure data describing a tool's interface and execution policy.
  Swarm doesn't execute tools — it yields ToolCalls for the caller to
  execute via the tool_executor function.

  Both `timeout_ms` and `on_timeout` are required. There are no defaults —
  every tool must explicitly declare its execution policy. Missing either
  field raises at construction time.

  `on_timeout` semantics:
  - `:error` — return an error ToolResult to the LLM, agent continues
  - `:pause_agent` — halt the agent loop cleanly; the caller persists context
    and restarts on the next user message
  """
  use TypedStruct

  typedstruct enforce: true do
    field(:name, String.t())
    field(:description, String.t())
    field(:parameter_schema, map())
    field(:timeout_ms, pos_integer())
    field(:on_timeout, :error | :pause_agent)
  end

  @doc """
  Creates a new tool definition.

  All five fields are required. Raises `ArgumentError` if any is missing
  or `KeyError` if an unknown key is provided.

  ## Example

      Tool.new(
        name: "question",
        description: "Ask the user a question",
        parameter_schema: %{},
        timeout_ms: 120_000,
        on_timeout: :pause_agent
      )
  """
  @spec new(keyword()) :: t()
  def new(attrs) do
    struct!(__MODULE__, attrs)
  end
end
