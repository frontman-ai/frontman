defmodule FrontmanServer.Agents.SpecializedAgent do
  @moduledoc """
  A unified agent struct for all specialized sub-agents.

  Instead of having separate modules for each agent type (FigmaBreakdownAgent,
  ComponentImplementAgent, etc.), this module provides a single struct with a
  `:type` field that determines the agent's behavior.

  The system prompt is retrieved from `Prompts.specialized/1` based on the type.

  API key resolution happens at the domain layer (Agents context) before the
  root agent runs. Sub-agents receive the resolved key via `llm_opts[:api_key]`
  passed through `Backend.Context`.

  ## Types

  - `:figma_breakdown` - Analyzes Figma designs and breaks them into components
  - `:component_implement` - Implements UI components from Figma designs
  - `:fix_files_errors` - Fixes compilation/runtime errors after implementation
  - `:visual_compare` - Compares implementation against Figma design
  - `:fix_visual_issues` - Fixes visual discrepancies based on comparison
  - `:replace_component` - Replaces old component with new implementation
  """

  use TypedStruct

  alias FrontmanServer.Agents.{LLMClient, Prompts}

  @type agent_type ::
          :figma_breakdown
          | :component_implement
          | :fix_files_errors
          | :visual_compare
          | :fix_visual_issues
          | :replace_component

  typedstruct do
    field(:type, agent_type(), enforce: true)
    field(:tools, [Swarm.Tool.t()], default: [])
    # llm_opts must include :api_key (resolved at domain layer, passed via Context)
    field(:llm_opts, keyword(), default: [])
    field(:model, String.t() | nil, default: nil)
  end

  @doc """
  Creates a new SpecializedAgent.

  ## Options

  - `:type` - The agent type (required)
  - `:tools` - List of Swarm.Tool structs
  - `:llm_opts` - LLM options, must include `:api_key`
  - `:model` - LLM model spec (defaults to LLMClient default)
  """
  @spec new(agent_type(), keyword()) :: t()
  def new(type, opts \\ []) do
    %__MODULE__{
      type: type,
      tools: Keyword.get(opts, :tools, []),
      llm_opts: Keyword.get(opts, :llm_opts, []),
      model: Keyword.get(opts, :model)
    }
  end
end

defimpl Swarm.Agent, for: FrontmanServer.Agents.SpecializedAgent do
  alias FrontmanServer.Agents.{LLMClient, Prompts, SpecializedAgent}

  def system_prompt(%SpecializedAgent{type: type}) do
    Prompts.specialized(type)
  end

  def llm(%SpecializedAgent{} = agent) do
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
