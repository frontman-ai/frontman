# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution.RootAgent do
  @moduledoc """
  Runnable root agent for a task turn.
  """

  use TypedStruct

  alias FrontmanServer.Accounts
  alias FrontmanServer.Tasks.Task
  alias FrontmanServer.Tools.MCP

  typedstruct enforce: true do
    field(:task, Task.t())
    field(:scope, Accounts.scope())
    field(:interaction_id, String.t() | nil)
    field(:tools, [SwarmAi.Tool.t()])
    field(:backend_tool_modules, [module()])
    field(:mcp_tool_defs, [MCP.t()])
    field(:system_prompt, String.t())
    field(:model, String.t() | map())
    field(:llm_opts, keyword())
  end
end

defimpl SwarmAi.Agent, for: FrontmanServer.Tasks.Execution.RootAgent do
  alias FrontmanServer.Frameworks
  alias FrontmanServer.Tasks.Execution.{LLMClient, RootAgent, ToolExecutor}
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.Task

  def id(%RootAgent{task: %Task{task_id: task_id}}), do: task_id

  def messages(%RootAgent{task: %Task{interactions: interactions}}) do
    Interaction.to_swarm_messages(interactions)
  end

  def context(%RootAgent{scope: scope, interaction_id: interaction_id}) do
    %{scope: scope, interaction_id: interaction_id}
  end

  def tool_executor(%RootAgent{scope: scope, task: task} = agent) do
    ToolExecutor.make(scope, task.task_id, %{
      backend_tool_modules: agent.backend_tool_modules,
      mcp_tool_defs: agent.mcp_tool_defs,
      execution_mode: Frameworks.tool_execution_mode(task.framework)
    })
  end

  def system_prompt(%RootAgent{system_prompt: system_prompt}), do: system_prompt

  def llm(%RootAgent{} = agent) do
    LLMClient.new(tools: agent.tools, llm_opts: agent.llm_opts, model: agent.model)
  end
end
