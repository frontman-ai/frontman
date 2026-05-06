# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution.RootAgent do
  @moduledoc """
  The main coordinating agent that handles user requests.

  This agent receives user messages, can use tools (including spawning sub-agents),
  and coordinates the overall task execution. It implements the SwarmAi.Agent protocol
  directly, owning its system prompt generation logic.

  The system prompt is dynamically built based on context:
  - Selected component information
  - Framework-specific guidance

  API key resolution happens at the domain layer (Tasks context) before this agent
  is created. The resolved key is passed via `llm_opts[:api_key]`.
  """

  use TypedStruct

  alias FrontmanServer.Tasks.Execution.Framework
  alias FrontmanServer.Tasks.Execution.{LLMClient, Prompts}

  typedstruct do
    field(:tools, [SwarmAi.Tool.t()], default: [])
    field(:has_annotations, boolean(), default: false)
    field(:has_typescript_react, boolean(), default: false)
    field(:framework, Framework.t() | nil, default: nil)
    # llm_opts must include :api_key (resolved at domain layer)
    # May also include :with_claude_subscription for OAuth
    field(:llm_opts, keyword(), default: [])
    field(:model, String.t() | nil, default: nil)
    # Discovered project rules (AGENTS.md, etc.) to append to system prompt
    field(:project_rules, list(), default: [])
    # Discovered project structure summary (from list_tree during MCP init)
    field(:project_structure, String.t() | nil, default: nil)
  end

  @doc """
  Creates a new RootAgent.

  ## Options

  - `:tools` - List of SwarmAi.Tool structs available to the agent
  - `:has_annotations` - Whether the user has annotated elements in the UI
  - `:framework` - `Framework.t()` struct for framework-specific guidance
  - `:llm_opts` - LLM options, must include `:api_key`. May include
    `:with_claude_subscription` for OAuth transformations.
  - `:model` - LLM model spec (defaults to LLMClient default)
  - `:project_rules` - List of discovered project rules (AGENTS.md, etc.)
  - `:project_structure` - Discovered project structure summary (from list_tree)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      tools: Keyword.get(opts, :tools, []),
      has_annotations: Keyword.get(opts, :has_annotations, false),
      has_typescript_react: Keyword.get(opts, :has_typescript_react, false),
      framework: Keyword.get(opts, :framework),
      llm_opts: Keyword.get(opts, :llm_opts, []),
      model: Keyword.get(opts, :model),
      project_rules: Keyword.get(opts, :project_rules, []),
      project_structure: Keyword.get(opts, :project_structure)
    }
  end
end

defimpl SwarmAi.Agent, for: FrontmanServer.Tasks.Execution.RootAgent do
  alias FrontmanServer.Tasks.Execution.{LLMClient, Prompts, RootAgent}

  def system_prompt(%RootAgent{} = agent) do
    # Build system prompt - always returns a string
    # OAuth transformations (identity prepend, content splitting) are handled by LLMClient
    Prompts.build(
      has_annotations: agent.has_annotations,
      has_typescript_react: agent.has_typescript_react,
      framework: agent.framework,
      project_rules: agent.project_rules,
      project_structure: agent.project_structure
    )
  end

  def llm(%RootAgent{} = agent) do
    opts =
      [
        tools: agent.tools,
        llm_opts: agent.llm_opts
      ]
      |> then(fn opts ->
        if agent.model, do: Keyword.put(opts, :model, agent.model), else: opts
      end)

    LLMClient.new(opts)
  end
end
