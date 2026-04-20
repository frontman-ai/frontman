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

  @base_backend_tools [
    FrontmanServer.Tools.TodoWrite,
    FrontmanServer.Tools.WebFetch
  ]

  @sandbox_backend_tools [
    FrontmanServer.Tools.Sandbox.EditFile,
    FrontmanServer.Tools.Sandbox.FileExists,
    FrontmanServer.Tools.Sandbox.Grep,
    FrontmanServer.Tools.Sandbox.ListFiles,
    FrontmanServer.Tools.Sandbox.ListTree,
    FrontmanServer.Tools.Sandbox.ReadFile,
    FrontmanServer.Tools.Sandbox.SearchFiles,
    FrontmanServer.Tools.Sandbox.WriteFile
  ]

  @todo_mutations [FrontmanServer.Tools.TodoWrite.name()]

  @spec backend_tool_modules() :: [module()]
  def backend_tool_modules, do: @base_backend_tools

  @spec backend_tool_modules(keyword()) :: [module()]
  def backend_tool_modules(opts) when is_list(opts) do
    case Keyword.get(opts, :sandbox) do
      nil -> @base_backend_tools
      _sandbox -> @base_backend_tools ++ @sandbox_backend_tools
    end
  end

  @spec sandbox_tool_modules() :: [module()]
  def sandbox_tool_modules, do: @sandbox_backend_tools

  @spec backend_tools() :: [SwarmAi.Tool.t()]
  def backend_tools do
    Enum.map(@base_backend_tools, &Backend.to_swarm_tool/1)
  end

  @spec backend_tools([module()]) :: [SwarmAi.Tool.t()]
  def backend_tools(modules) when is_list(modules) do
    Enum.map(modules, &Backend.to_swarm_tool/1)
  end

  @spec find_tool(String.t()) :: {:ok, module()} | :not_found
  def find_tool(tool_name) do
    all_backend_tools = @base_backend_tools ++ @sandbox_backend_tools

    case Enum.find(all_backend_tools, fn mod -> mod.name() == tool_name end) do
      nil -> :not_found
      mod -> {:ok, mod}
    end
  end

  @doc """
  Returns the execution target for a tool.

  Backend tools are executed server-side by ToolExecutor.
  MCP tools are routed to the browser client for execution.
  """
  @spec execution_target(String.t()) :: :backend | :mcp
  def execution_target(tool_name) do
    execution_target(tool_name, @base_backend_tools)
  end

  @spec execution_target(String.t(), [module()]) :: :backend | :mcp
  def execution_target(tool_name, backend_modules) when is_list(backend_modules) do
    case Enum.find(backend_modules, fn mod -> mod.name() == tool_name end) do
      nil -> :mcp
      _module -> :backend
    end
  end

  @spec todo_mutation?(String.t()) :: boolean()
  def todo_mutation?(tool_name), do: tool_name in @todo_mutations

  @doc """
  Prepares all available tools for a task.

  Aggregates backend tools and MCP tools into LLM format.
  MCP tools are passed through the agent execution chain via Backend.Context.

  ## Example
      mcp_tools |> Tools.prepare_for_task(task_id)
  """
  @spec prepare_for_task([FrontmanServer.Tools.MCP.t()], String.t()) :: [SwarmAi.Tool.t()]
  def prepare_for_task(mcp_tools, task_id) do
    prepare_for_task(mcp_tools, task_id, [])
  end

  @spec prepare_for_task([FrontmanServer.Tools.MCP.t()], String.t(), keyword()) :: [
          SwarmAi.Tool.t()
        ]
  def prepare_for_task(mcp_tools, _task_id, opts) do
    backend_tool_modules = Keyword.get(opts, :backend_tool_modules, @base_backend_tools)
    backend = backend_tools(backend_tool_modules)

    backend_tool_names =
      backend_tool_modules
      |> Enum.map(& &1.name())
      |> MapSet.new()

    mcp_formatted =
      mcp_tools
      |> Enum.reject(fn tool -> MapSet.member?(backend_tool_names, tool.name) end)
      |> MCP.to_swarm_tools()

    backend ++ mcp_formatted
  end
end
