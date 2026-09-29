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
  alias FrontmanServer.Tools.Skill

  @todo_mutations [FrontmanServer.Tools.TodoWrite.name()]

  def resolve(policy, mcp_tools) when is_list(mcp_tools) do
    mcp_tools
    |> Map.new(&{&1.name, &1})
    |> Map.merge(Map.new(backend_tool_modules(), &{&1.name(), &1}))
    |> Map.filter(fn
      {_name, %MCP{visible_to_agent: false}} -> false
      {_name, %MCP{access: access}} -> allowed?(access, policy)
      {_name, module} when is_atom(module) -> allowed?(module.access(), policy)
    end)
  end

  def backend_tool_modules do
    Application.fetch_env!(:frontman_server, :backend_tools)
  end

  @doc "Whether the resolved tools include backend skill loading."
  def supports_skills?(tools) when is_map(tools),
    do: Map.get(tools, Skill.name()) == Skill

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

  def to_swarm_tools(tools) when is_map(tools) do
    tools
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn
      {_name, %MCP{} = tool} -> MCP.to_swarm_tool(tool)
      {_name, module} when is_atom(module) -> Backend.to_swarm_tool(module)
    end)
  end

  defp allowed?(_access, :all), do: true
  defp allowed?(access, %{access: allowed}) when is_list(allowed), do: access in allowed
end
