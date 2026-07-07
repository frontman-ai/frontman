# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.MCP do
  @moduledoc """
  Utilities for MCP tools from external clients.
  """

  @enforce_keys [:name, :description, :input_schema, :timeout_ms, :on_timeout]
  defstruct name: nil,
            description: nil,
            input_schema: nil,
            access: :read_write,
            visible_to_agent: true,
            timeout_ms: nil,
            on_timeout: nil

  # The MCP spec has no timeout fields in tools/list — timeout policy is a
  # client-side concern (frontman server is the MCP client here). These
  # defaults are applied to all tools discovered from external MCP servers.
  @default_timeout_ms 600_000
  @default_on_timeout :error

  def from_map(tool) when is_map(tool) do
    {timeout_ms, on_timeout} = timeout_policy(tool["executionMode"])

    %__MODULE__{
      name: tool["name"],
      description: tool["description"] || "",
      input_schema: tool["inputSchema"] || %{"type" => "object", "properties" => %{}},
      access: parse_access(tool["access"]),
      visible_to_agent: Map.get(tool, "visibleToAgent", true),
      timeout_ms: timeout_ms,
      on_timeout: on_timeout
    }
  end

  # Interactive tools pause the agent and wait for user input; they need a
  # shorter timeout (2 min) so the agent isn't blocked indefinitely if the
  # user never responds. All other tools use the default long timeout.
  defp timeout_policy("interactive"), do: {120_000, :pause_agent}
  defp timeout_policy(_), do: {@default_timeout_ms, @default_on_timeout}

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
      parameter_schema: tool.input_schema,
      timeout_ms: tool.timeout_ms,
      on_timeout: tool.on_timeout
    )
  end
end
