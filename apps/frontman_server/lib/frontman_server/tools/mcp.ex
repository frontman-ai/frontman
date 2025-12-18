defmodule FrontmanServer.Tools.MCP do
  @moduledoc """
  Utilities for MCP tools from external clients.
  """

  use TypedStruct

  typedstruct enforce: true do
    field :name, String.t()
    field :description, String.t()
    field :input_schema, map()
    field :visible_to_agent, boolean(), default: true
  end

  @spec from_map(map()) :: t()
  def from_map(tool) when is_map(tool) do
    %__MODULE__{
      name: tool["name"],
      description: tool["description"] || "",
      input_schema: tool["inputSchema"] || %{"type" => "object", "properties" => %{}},
      visible_to_agent: Map.get(tool, "visibleToAgent", true)
    }
  end

  @spec from_maps([map()]) :: [t()]
  def from_maps(tools) when is_list(tools) do
    Enum.map(tools, &from_map/1)
  end

  @spec to_llm_format([t()]) :: [ReqLLM.Tool.t()]
  def to_llm_format(mcp_tools) when is_list(mcp_tools) do
    mcp_tools
    |> Enum.filter(& &1.visible_to_agent)
    |> Enum.map(&convert_tool/1)
  end

  defp convert_tool(%__MODULE__{} = tool) do
    ReqLLM.Tool.new!(
      name: tool.name,
      description: tool.description,
      parameter_schema: tool.input_schema,
      # MCP tools are executed externally via TaskChannel routing
      callback: fn _args -> {:ok, nil} end
    )
  end
end
