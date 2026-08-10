# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.MCP do
  @moduledoc """
  Utilities for MCP tools from external clients.
  """

  @enforce_keys [:name, :input_schema, :timeout_ms, :on_timeout]
  defstruct name: nil,
            title: nil,
            description: nil,
            input_schema: nil,
            output_schema: nil,
            icons: nil,
            annotations: nil,
            meta: nil,
            access: :read_write,
            visible_to_agent: true,
            timeout_ms: nil,
            on_timeout: nil

  @default_timeout_ms 600_000
  @default_on_timeout :error

  @spec from_map(map()) :: %__MODULE__{}
  def from_map(tool) when is_map(tool) do
    %__MODULE__{
      name: Map.fetch!(tool, "name"),
      title: tool["title"],
      description: tool["description"] || "",
      input_schema: Map.fetch!(tool, "inputSchema"),
      output_schema: tool["outputSchema"],
      icons: tool["icons"],
      annotations: tool["annotations"],
      meta: tool["_meta"],
      timeout_ms: @default_timeout_ms,
      on_timeout: @default_on_timeout
    }
  end

  @spec from_maps(list(map())) :: list(%__MODULE__{})
  def from_maps(tools) when is_list(tools) do
    Enum.map(tools, &from_map/1)
  end

  @spec to_swarm_tools(list(%__MODULE__{})) :: list(SwarmAi.Tool.t())
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
      parameter_schema: tool.input_schema,
      timeout_ms: tool.timeout_ms,
      on_timeout: tool.on_timeout
    )
  end
end
