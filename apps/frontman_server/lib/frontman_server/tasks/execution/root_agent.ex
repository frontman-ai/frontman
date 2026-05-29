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
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Frameworks
  alias FrontmanServer.Tasks.Task
  alias FrontmanServer.Tools.MCP

  typedstruct enforce: true do
    field(:task, Task.t())
    field(:scope, Accounts.scope())
    field(:interaction_id, String.t() | nil)
    field(:tools, [SwarmAi.Tool.t()])
    field(:backend_tool_modules, [module()])
    field(:mcp_tool_defs, [MCP.t()])
    field(:project_traits, [Frameworks.project_trait()])
    field(:model, String.t() | map())
    field(:llm_opts, keyword())
  end

  @doc "Creates a runnable root agent."
  @spec new(map()) :: t()
  def new(%{task: %Task{}, scope: %Scope{}} = attrs), do: struct!(__MODULE__, attrs)

  @doc "Returns the stable SwarmAi agent id for a task."
  @spec id(Task.t()) :: String.t()
  def id(%Task{task_id: task_id}) when is_binary(task_id), do: task_id
end

defimpl SwarmAi.Agent, for: FrontmanServer.Tasks.Execution.RootAgent do
  alias FrontmanServer.Frameworks
  alias FrontmanServer.Tasks.Execution.{LLMClient, Prompts, RootAgent, ToolExecutor}
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.Task

  def id(%RootAgent{task: %Task{} = task}), do: RootAgent.id(task)

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

  def system_prompt(%RootAgent{task: task} = agent) do
    Prompts.build(
      has_annotations: Interaction.has_annotations?(task.interactions),
      project_traits: agent.project_traits,
      framework: task.framework,
      project_rules: project_rules(task.interactions),
      project_structure: project_structure(task.interactions)
    )
  end

  def llm(%RootAgent{} = agent) do
    LLMClient.new(tools: agent.tools, llm_opts: agent.llm_opts, model: agent.model)
  end

  defp project_rules(interactions) do
    Enum.filter(interactions, &match?(%Interaction.DiscoveredProjectRule{}, &1))
  end

  defp project_structure(interactions) do
    case Enum.find(interactions, &match?(%Interaction.DiscoveredProjectStructure{}, &1)) do
      nil -> nil
      struct -> struct.summary
    end
  end
end
