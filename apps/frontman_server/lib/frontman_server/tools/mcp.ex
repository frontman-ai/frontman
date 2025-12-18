defmodule FrontmanServer.Tools.MCP do
  @moduledoc """
  Utilities for MCP tools from external clients.
  """

  @spec to_llm_format([map()]) :: [ReqLLM.Tool.t()]
  def to_llm_format(mcp_tools) when is_list(mcp_tools) do
    Enum.map(mcp_tools, &convert_tool/1)
  end

  defp convert_tool(tool) when is_map(tool) do
    ReqLLM.Tool.new!(
      name: tool["name"],
      description: tool["description"] || "",
      parameter_schema: tool["inputSchema"] || %{"type" => "object", "properties" => %{}},
      # MCP tools are executed externally via TaskChannel routing
      callback: fn _args -> {:ok, nil} end
    )
  end
end
