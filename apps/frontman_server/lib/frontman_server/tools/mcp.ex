# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.MCP do
  @moduledoc """
  Utilities for MCP tools from external clients.
  """

  @enforce_keys [:name, :description, :input_schema, :timeout_ms, :execution_mode]
  defstruct name: nil,
            description: nil,
            input_schema: nil,
            output_schema: nil,
            access: :read_write,
            visible_to_agent: true,
            timeout_ms: nil,
            execution_mode: nil

  @default_timeout_ms 600_000
  @tool_metadata_extension "ai.frontman/tool-metadata"

  def from_map(tool) when is_map(tool) do
    metadata = get_in(tool, ["_meta", @tool_metadata_extension]) || %{}
    execution_mode = parse_execution_mode(metadata["executionMode"])

    %__MODULE__{
      name: tool["name"],
      description: tool["description"] || "",
      input_schema: tool["inputSchema"] || %{"type" => "object", "properties" => %{}},
      output_schema: tool["outputSchema"],
      access: parse_access(metadata["access"]),
      visible_to_agent: Map.get(metadata, "visibleToAgent", true),
      timeout_ms: deadline(execution_mode),
      execution_mode: execution_mode
    }
  end

  defp parse_execution_mode("Interactive"), do: :interactive
  defp parse_execution_mode(mode) when mode in [nil, "Synchronous"], do: :synchronous

  defp deadline(:interactive), do: :infinity
  defp deadline(:synchronous), do: @default_timeout_ms

  defp parse_access("read"), do: :read
  defp parse_access("write"), do: :write
  defp parse_access("read-write"), do: :read_write
  defp parse_access(_), do: :read_write

  def from_maps(tools) when is_list(tools) do
    Enum.map(tools, &from_map/1)
  end

  def to_swarm_tools(mcp_tools) when is_list(mcp_tools) do
    mcp_tools
    |> Enum.filter(& &1.visible_to_agent)
    |> Enum.map(&to_swarm_tool/1)
  end

  defp to_swarm_tool(%__MODULE__{} = tool) do
    SwarmAi.Tool.new(
      name: tool.name,
      description: tool.description,
      access: tool.access,
      parameter_schema: tool.input_schema
    )
  end
end
