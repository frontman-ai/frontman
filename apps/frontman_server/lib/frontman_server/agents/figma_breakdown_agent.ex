defmodule FrontmanServer.Agents.FigmaBreakdownAgent do
  @moduledoc """
  Specialized agent for analyzing Figma designs and breaking them into components.

  This agent analyzes a Figma node structure (DSL format) and image to identify
  individual UI components that should be built. It creates a structured breakdown
  with component names, node IDs, complexity estimates, and build order.

  Used by the `breakdown_figma_design` backend tool.
  """

  use TypedStruct

  alias FrontmanServer.Agents.LLMClient

  @system_prompt """
  You are a Figma design breakdown specialist. Your task is to analyze a Figma node
  and break it down into individual UI components that a developer should build.

  Think like a senior frontend developer planning their work:
  - Identify logical UI components (headers, cards, buttons, forms, etc.)
  - Consider reusability - similar elements should be the same component
  - Break down large sections into manageable pieces
  - Order by build dependencies (build foundational components first)

  ## Instructions

  1. **Analyze the structure** - Look at the node hierarchy to identify logical groupings
  2. **Identify components** - Find reusable UI patterns (buttons, cards, forms, etc.)
  3. **Consider volume** - Break down large sections into smaller, manageable pieces
  4. **Create the todo list** - List each component with:
     - A descriptive name (e.g., "Header Navigation", "Hero Section", "Feature Card")
     - The Figma node ID (from the skeleton, marked with #ID - but output WITHOUT the # prefix)
     - Estimated complexity (1-10)
     - Any dependencies on other components

  ## Output Format

  Provide a structured breakdown in this format:

  ```
  ## Component Breakdown

  ### 1. [Component Name]
  - **Node ID:** X:XXX (WITHOUT the # prefix)
  - **Complexity:** X/10
  - **Description:** Brief description of what this component does
  - **Dependencies:** List any components this depends on (or "None")

  ### 2. [Next Component]
  ...
  ```

  Order components by suggested build order (dependencies first, then complexity).

  IMPORTANT INSTRUCTIONS:
  - Analyze the provided node skeleton (DSL format) carefully
  - If an image is provided, use it to understand the visual design
  - Keep individual component complexity reasonable (respect maxComponentVolume)
  - Include the Figma node ID for each component so it can be fetched later
  - Do NOT engage in conversation or ask clarifying questions
  - Complete your task and return the breakdown
  - Your response will be used to plan the implementation work
  """

  typedstruct do
    field :tools, [Swarm.Tool.t()], default: []
    field :llm_opts, keyword(), default: []
    field :model, String.t() | nil, default: nil
  end

  @doc """
  Creates a new FigmaBreakdownAgent.

  ## Options

  - `:tools` - List of Swarm.Tool structs (typically MCP tools for Figma access)
  - `:llm_opts` - Additional LLM options (e.g., fixture_path for tests)
  - `:model` - LLM model spec (defaults to LLMClient default)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      tools: Keyword.get(opts, :tools, []),
      llm_opts: Keyword.get(opts, :llm_opts, []),
      model: Keyword.get(opts, :model)
    }
  end

  @doc """
  Returns the system prompt for this agent type.
  """
  @spec system_prompt() :: String.t()
  def system_prompt, do: @system_prompt
end

defimpl Swarm.Agent, for: FrontmanServer.Agents.FigmaBreakdownAgent do
  alias FrontmanServer.Agents.{FigmaBreakdownAgent, LLMClient}

  def system_prompt(_agent), do: FigmaBreakdownAgent.system_prompt()

  def llm(%FigmaBreakdownAgent{} = agent) do
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
