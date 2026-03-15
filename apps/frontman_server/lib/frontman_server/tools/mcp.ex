defmodule FrontmanServer.Tools.MCP do
  @moduledoc """
  Utilities for MCP tools from external clients.
  """

  use TypedStruct

  @type execution_mode :: :synchronous | :interactive

  typedstruct enforce: true do
    field(:name, String.t())
    field(:description, String.t())
    field(:input_schema, map())
    field(:visible_to_agent, boolean(), default: true)
    field(:execution_mode, execution_mode(), default: :synchronous)
  end

  @spec from_map(map()) :: t()
  def from_map(tool) when is_map(tool) do
    %__MODULE__{
      name: tool["name"],
      description: tool["description"] || "",
      input_schema: tool["inputSchema"] || %{"type" => "object", "properties" => %{}},
      visible_to_agent: Map.get(tool, "visibleToAgent", true),
      execution_mode: parse_execution_mode(tool["executionMode"])
    }
  end

  defp parse_execution_mode(value) when is_binary(value) do
    case String.downcase(value) do
      "interactive" -> :interactive
      _ -> :synchronous
    end
  end

  defp parse_execution_mode(_), do: :synchronous

  @doc "Returns true if the tool blocks with a longer timeout to await user input."
  @spec interactive?(t()) :: boolean()
  def interactive?(%__MODULE__{execution_mode: :interactive}), do: true
  def interactive?(%__MODULE__{}), do: false

  @doc "Looks up a tool by name and returns whether it is interactive."
  @spec interactive_by_name?([t()], String.t()) :: boolean()
  def interactive_by_name?(mcp_tools, name) do
    case Enum.find(mcp_tools, &(&1.name == name)) do
      %__MODULE__{} = tool -> interactive?(tool)
      nil -> false
    end
  end

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
    SwarmAi.Tool.new(tool.name, tool.description, tool.input_schema)
  end
end
