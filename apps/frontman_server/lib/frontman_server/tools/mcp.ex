defmodule FrontmanServer.Tools.MCP do
  @moduledoc """
  Utilities for MCP tools from external clients.
  """

  use TypedStruct

  typedstruct enforce: true do
    field(:name, String.t())
    field(:description, String.t())
    field(:input_schema, map())
    field(:visible_to_agent, boolean(), default: true)
    field(:timeout_ms, pos_integer())
    field(:on_timeout, :error | :pause_agent)
  end

  @spec from_map(map()) :: t()
  def from_map(tool) when is_map(tool) do
    %__MODULE__{
      name: tool["name"],
      description: tool["description"] || "",
      input_schema: tool["inputSchema"] || %{"type" => "object", "properties" => %{}},
      visible_to_agent: Map.get(tool, "visibleToAgent", true),
      timeout_ms: Map.fetch!(tool, "timeoutMs"),
      on_timeout: parse_on_timeout(Map.fetch!(tool, "onTimeout"))
    }
  end

  defp parse_on_timeout("pause_agent"), do: :pause_agent
  defp parse_on_timeout(_), do: :error

  @spec from_maps([map()]) :: [t()]
  def from_maps(tools) when is_list(tools) do
    Enum.map(tools, &from_map/1)
  end

  @spec to_swarm_tools([t()]) :: [SwarmAi.Tool.t()]
  def to_swarm_tools(mcp_tools) when is_list(mcp_tools) do
    mcp_tools
    |> Enum.filter(& &1.visible_to_agent)
    |> Enum.map(&to_swarm_tool/1)
  end

  defp to_swarm_tool(%__MODULE__{} = tool) do
    SwarmAi.Tool.new(
      name: tool.name,
      description: tool.description,
      parameter_schema: tool.input_schema,
      timeout_ms: tool.timeout_ms,
      on_timeout: tool.on_timeout
    )
  end
end
