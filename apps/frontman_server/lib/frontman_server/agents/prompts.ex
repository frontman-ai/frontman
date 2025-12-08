defmodule FrontmanServer.Agents.Prompts do
  @moduledoc """
  Manages system prompts and role configurations for agents.

  Root agents receive the base system prompt plus sub-agent guidance.
  Sub-agents receive role-specific prompts based on their assigned role.
  """

  @base_system_prompt """
  You are a coding assistant for a Next.js app (TypeScript, React, Tailwind, some ReScript output).

  ## Rules

  - Paths relative to repo root.
  - List → Read → Modify. Never edit unseen files.
  - Keep diffs small and reversible. Match repo style.
  - After 2 failed tool calls, ask one clarifying question.

  ## ReScript handling (explicit)

  - Treat generated files (*.res.mjs) as read-only.
  - Always edit the source *.res.
  - Procedure when you see X.res.mjs:
    1. Locate X.res by name/path. If not found, search siblings or module index.
    2. read_file both X.res and X.res.mjs to understand mapping and exports.
    3. Apply changes to X.res only. Preserve types and module boundaries.
  - If no matching *.res exists or mapping is unclear, stop and ask for the exact source path.
  - Never write to generated artifacts. Note this in the output if a change seems required there.

  ## Next.js

  - Detect router (app/pages) and stick to it.
  - "use client" only when required.
  - Keep server actions and non-serializable logic on the server.

  ## TypeScript / React / Tailwind

  - Avoid any. Prefer discriminated unions.
  - Pure components and stable hooks.
  - Use Tailwind utilities and existing tokens.

  ## Output

  - Short plan
  - Single unified diff block
  - Brief notes: build/test results or follow-ups
  """

  @roles %{
    research: %{
      name: "ResearchAgent",
      description: "Investigates questions, finds information, analyzes data",
      system_prompt: """
      You are a research specialist. Your task is to investigate and find information.

      IMPORTANT INSTRUCTIONS:
      - Focus ONLY on the specific task assigned to you
      - Return a concise summary of your findings
      - Do NOT engage in conversation or ask clarifying questions
      - Do NOT include unnecessary context or explanations
      - Complete your task and return a final answer
      - Your response will be incorporated into a larger workflow
      """
    },
    planning: %{
      name: "PlanningAgent",
      description: "Breaks down complex tasks, creates step-by-step plans",
      system_prompt: """
      You are a planning specialist. Your task is to break down complex tasks into actionable steps.

      IMPORTANT INSTRUCTIONS:
      - Focus ONLY on the specific task assigned to you
      - Return a clear, structured plan
      - Do NOT engage in conversation or ask clarifying questions
      - Do NOT include unnecessary context or explanations
      - Complete your task and return a final answer
      - Your response will be incorporated into a larger workflow
      """
    },
    validator: %{
      name: "ValidatorAgent",
      description: "Validates work completeness, checks for errors or omissions",
      system_prompt: """
      You are a validation specialist. Your task is to check work for completeness and correctness.

      IMPORTANT INSTRUCTIONS:
      - Focus ONLY on the specific task assigned to you
      - Return a concise validation report
      - Do NOT engage in conversation or ask clarifying questions
      - Do NOT include unnecessary context or explanations
      - Complete your task and return a final answer
      - Your response will be incorporated into a larger workflow
      """
    }
  }

  @type role :: :research | :planning | :validator

  @type role_config :: %{
          name: String.t(),
          description: String.t(),
          system_prompt: String.t()
        }

  # Role Configuration API

  @doc "Returns all available role keys"
  @spec roles() :: [role()]
  def roles, do: Map.keys(@roles)

  @doc "Gets role configuration by key"
  @spec get_role(role()) :: {:ok, role_config()} | {:error, :not_found}
  def get_role(key) when is_atom(key) do
    case Map.get(@roles, key) do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  @doc "Parses a string into a role atom"
  @spec parse_role(String.t()) :: {:ok, role()} | {:error, :not_found}
  def parse_role(key_string) when is_binary(key_string) do
    key = String.to_existing_atom(key_string)
    if Map.has_key?(@roles, key), do: {:ok, key}, else: {:error, :not_found}
  rescue
    ArgumentError -> {:error, :not_found}
  end

  # Prompt Building API

  @doc """
  Builds a complete system message for the LLM.

  Returns a ReqLLM system message with cache control.
  Pass `nil` for root agents, or a role atom for sub-agents.

  ## Options
  - `:has_figma_context` - When true, adds Figma-specific guidance for breaking down designs
  """
  @spec build_system_message(atom() | nil, keyword()) :: map()
  def build_system_message(role, opts \\ []) do
    system_prompt = build(role, opts)
    ReqLLM.Context.system(system_prompt, cache_control: %{type: "ephemeral"})
  end

  @doc """
  Builds the system prompt text for an agent.

  For root agents (role: nil), returns the base prompt with sub-agent guidance.
  For sub-agents, returns the role-specific prompt.

  ## Options
  - `:has_figma_context` - When true, adds Figma-specific guidance for breaking down designs
  """
  @spec build(atom() | nil, keyword()) :: String.t()
  def build(role, opts \\ [])

  def build(nil, opts) do
    base = @base_system_prompt <> "\n" <> sub_agent_guidance()

    if Keyword.get(opts, :has_figma_context, false) do
      base <> "\n" <> figma_context_guidance()
    else
      base
    end
  end

  def build(role, _opts) do
    {:ok, config} = get_role(role)
    config.system_prompt
  end

  defp figma_context_guidance do
    """
    ## Figma Design Context Detected

    You have received Figma design context (a design image and/or node DSL structure).

    Use this context to understand the visual design and implement components accordingly.
    The Figma node data includes layout, styling, and hierarchy information that should guide your implementation.
    """
  end

  defp sub_agent_guidance do
    role_list =
      roles()
      |> Enum.map(fn role ->
        {:ok, config} = get_role(role)
        "- **#{role}**: #{config.description}"
      end)
      |> Enum.join("\n")

    """
    ## Sub-agents

    Use `spawn_sub_agent` to delegate specialized work:
    #{role_list}

    Spawn sub-agents early for complex tasks. They run autonomously and return results.
    """
  end
end
