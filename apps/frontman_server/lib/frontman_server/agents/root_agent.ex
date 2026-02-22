defmodule FrontmanServer.Agents.RootAgent do
  @moduledoc """
  The main coordinating agent that handles user requests.

  This agent receives user messages, can use tools (including spawning sub-agents),
  and coordinates the overall task execution. It implements the SwarmAi.Agent protocol
  directly, owning its system prompt generation logic.

  The system prompt is dynamically built based on context:
  - Selected component information
  - Framework-specific guidance

  API key resolution happens at the domain layer (Agents context) before this agent
  is created. The resolved key is passed via `llm_opts[:api_key]`.
  """

  use TypedStruct

  alias FrontmanServer.Agents.{LLMClient, Prompts}

  typedstruct do
    field(:tools, [SwarmAi.Tool.t()], default: [])
    field(:has_selected_component, boolean(), default: false)
    field(:has_current_page, boolean(), default: false)
    field(:has_typescript_react, boolean(), default: false)
    field(:framework, String.t() | nil, default: nil)
    # llm_opts must include :api_key (resolved at domain layer)
    # May also include :requires_mcp_prefix and :identity_override for OAuth
    field(:llm_opts, keyword(), default: [])
    field(:model, String.t() | nil, default: nil)
    # Discovered project rules (AGENTS.md, etc.) to append to system prompt
    field(:project_rules, list(), default: [])
  end

  @doc """
  Creates a new RootAgent.

  ## Options

  - `:tools` - List of SwarmAi.Tool structs available to the agent
  - `:has_selected_component` - Whether a component is selected in the codebase
  - `:has_current_page` - Whether current page context is available
  - `:framework` - Framework name (e.g., "nextjs") for framework-specific guidance
  - `:llm_opts` - LLM options, must include `:api_key`. May include `:requires_mcp_prefix`
    and `:identity_override` for OAuth transformations (handled by LLMClient).
  - `:model` - LLM model spec (defaults to LLMClient default)
  - `:project_rules` - List of discovered project rules (AGENTS.md, etc.)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      tools: Keyword.get(opts, :tools, []),
      has_selected_component: Keyword.get(opts, :has_selected_component, false),
      has_current_page: Keyword.get(opts, :has_current_page, false),
      has_typescript_react: Keyword.get(opts, :has_typescript_react, false),
      framework: Keyword.get(opts, :framework),
      llm_opts: Keyword.get(opts, :llm_opts, []),
      model: Keyword.get(opts, :model),
      project_rules: Keyword.get(opts, :project_rules, [])
    }
  end
end

defimpl SwarmAi.Agent, for: FrontmanServer.Agents.RootAgent do
  alias FrontmanServer.Agents.{LLMClient, Prompts, RootAgent}

  def system_prompt(%RootAgent{} = agent) do
    # Build system prompt - always returns a string
    # OAuth transformations (identity prepend, content splitting) are handled by LLMClient
    Prompts.build(
      has_selected_component: agent.has_selected_component,
      has_current_page: agent.has_current_page,
      has_typescript_react: agent.has_typescript_react,
      framework: agent.framework,
      project_rules: agent.project_rules
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

  def init(_agent), do: {:ok, %{}, []}

  def should_terminate?(_agent, _loop, _state), do: false
end
