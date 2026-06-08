# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution.RootAgent do
  @moduledoc """
  Runnable root agent for a task turn.
  """

  alias FrontmanServer.Tasks.TaskSchema

  @enforce_keys [
    :task,
    :scope,
    :turn_number,
    :messages,
    :tools,
    :backend_tool_modules,
    :mcp_tool_defs,
    :system_prompt,
    :model,
    :llm_opts
  ]
  defstruct task: nil,
            scope: nil,
            turn_number: nil,
            messages: nil,
            tools: nil,
            backend_tool_modules: nil,
            mcp_tool_defs: nil,
            system_prompt: nil,
            model: nil,
            llm_opts: nil
end

defimpl SwarmAi.Agent, for: FrontmanServer.Tasks.Execution.RootAgent do
  alias FrontmanServer.Frameworks
  alias FrontmanServer.Tasks.Execution.{LLMClient, RootAgent, ToolExecutor}
  alias FrontmanServer.Tasks.TaskSchema

  def id(%RootAgent{task: %TaskSchema{id: task_id}}), do: task_id

  def messages(%RootAgent{messages: messages}), do: messages

  def context(%RootAgent{scope: scope, turn_number: turn_number}) do
    %{scope: scope, turn_number: turn_number}
  end

  def tool_executor(%RootAgent{scope: scope, task: task, turn_number: turn_number} = agent) do
    ToolExecutor.make(scope, task.id, turn_number, %{
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
