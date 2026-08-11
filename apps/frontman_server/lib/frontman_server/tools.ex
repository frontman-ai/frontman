# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools do
  @moduledoc """
  Backend tool aggregator.
  """

  alias FrontmanServer.Tools.Backend
  alias FrontmanServer.Tools.MCP

  @todo_mutations [FrontmanServer.Tools.TodoWrite.name()]

  def backend_tool_modules, do: backend_tool_modules(:all)

  def backend_tool_modules(:all) do
    Application.fetch_env!(:frontman_server, :backend_tools)
  end

  def backend_tool_modules(%{access: access}) when is_list(access) do
    Enum.filter(backend_tool_modules(), &(&1.access() in access))
  end

  def backend_tools do
    Enum.map(backend_tool_modules(), &Backend.to_swarm_tool/1)
  end

  def find_tool(tool_name) do
    case Enum.find(backend_tool_modules(), fn mod -> mod.name() == tool_name end) do
      nil -> :not_found
      mod -> {:ok, mod}
    end
  end

  @doc """
  Returns the execution target for a tool.

  Backend tools are executed server-side by ToolExecutor.
  MCP tools are routed to the browser client for execution.
  """
  def execution_target(tool_name) do
    case find_tool(tool_name) do
      {:ok, _module} -> :backend
      :not_found -> :mcp
    end
  end

  def todo_mutation?(tool_name), do: tool_name in @todo_mutations

  def mcp_tools(mcp_tools, :all), do: Enum.filter(mcp_tools, & &1.visible_to_agent)

  def mcp_tools(mcp_tools, %{access: access}) when is_list(access) do
    Enum.filter(mcp_tools, &(&1.visible_to_agent and &1.access in access))
  end

  def to_swarm_tools(backend_tool_modules, mcp_tools) do
    Enum.map(backend_tool_modules, &Backend.to_swarm_tool/1) ++ MCP.to_swarm_tools(mcp_tools)
  end
end
