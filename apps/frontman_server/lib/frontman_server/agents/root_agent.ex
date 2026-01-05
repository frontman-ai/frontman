defmodule FrontmanServer.Agents.RootAgent do
  @moduledoc """
  The main coordinating agent that handles user requests.

  This agent receives user messages, can use tools (including spawning sub-agents),
  and coordinates the overall task execution. It implements the Swarm.Agent protocol
  directly, owning its system prompt generation logic.

  The system prompt is dynamically built based on context:
  - Figma design context
  - Selected component information
  - Framework-specific guidance
  """

  use TypedStruct

  alias FrontmanServer.Agents.{LLMClient, Prompts}

  typedstruct do
    field :tools, [Swarm.Tool.t()], default: []
    field :has_figma_context, boolean(), default: false
    field :has_selected_component, boolean(), default: false
    field :figma_node_id, String.t() | nil, default: nil
    field :framework, String.t() | nil, default: nil
    field :llm_opts, keyword(), default: []
    field :model, String.t() | nil, default: nil
  end

  @doc """
  Creates a new RootAgent.

  ## Options

  - `:tools` - List of Swarm.Tool structs available to the agent
  - `:has_figma_context` - Whether Figma design context is present
  - `:has_selected_component` - Whether a component is selected in the codebase
  - `:figma_node_id` - The Figma node ID for breakdown_figma_design
  - `:framework` - Framework name (e.g., "nextjs") for framework-specific guidance
  - `:llm_opts` - Additional LLM options (e.g., fixture_path for tests)
  - `:model` - LLM model spec (defaults to LLMClient default)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      tools: Keyword.get(opts, :tools, []),
      has_figma_context: Keyword.get(opts, :has_figma_context, false),
      has_selected_component: Keyword.get(opts, :has_selected_component, false),
      figma_node_id: Keyword.get(opts, :figma_node_id),
      framework: Keyword.get(opts, :framework),
      llm_opts: Keyword.get(opts, :llm_opts, []),
      model: Keyword.get(opts, :model)
    }
  end
end

defimpl Swarm.Agent, for: FrontmanServer.Agents.RootAgent do
  alias FrontmanServer.Agents.{LLMClient, Prompts, RootAgent}

  def system_prompt(%RootAgent{} = agent) do
    Prompts.build(
      has_figma_context: agent.has_figma_context,
      has_selected_component: agent.has_selected_component,
      figma_node_id: agent.figma_node_id,
      framework: agent.framework
    )
  end

  def llm(%RootAgent{} = agent) do
    opts =
      [tools: agent.tools, llm_opts: agent.llm_opts]
      |> then(fn opts ->
        if agent.model, do: Keyword.put(opts, :model, agent.model), else: opts
      end)

    LLMClient.new(opts)
  end

  def init(_agent), do: {:ok, %{}, []}

  def should_terminate?(_agent, _loop, _state), do: false
end
