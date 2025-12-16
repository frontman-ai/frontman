defmodule FrontmanServer.Agents.Prompts do
  @moduledoc """
  Manages system prompts for agents.
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

  # Prompt Building API

  @doc """
  Builds a complete system message for the LLM.

  Returns a ReqLLM system message with cache control.

  ## Options
  - `:has_figma_context` - When true, adds Figma-specific guidance for breaking down designs
  """
  @spec build_system_message(atom() | nil, keyword()) :: map()
  def build_system_message(_role, opts \\ []) do
    system_prompt = build(opts)
    ReqLLM.Context.system(system_prompt, cache_control: %{type: "ephemeral"})
  end

  @doc """
  Builds the system prompt text for an agent.

  ## Options
  - `:has_figma_context` - When true, adds Figma-specific guidance for breaking down designs
  """
  @spec build(keyword()) :: String.t()
  def build(opts \\ []) do
    if Keyword.get(opts, :has_figma_context, false) do
      @base_system_prompt <> "\n" <> figma_context_guidance()
    else
      @base_system_prompt
    end
  end

  defp figma_context_guidance do
    """
    ## Figma Design Context Detected

    You have received Figma design context (a design image and/or node DSL structure).

    Use this context to understand the visual design and implement components accordingly.
    The Figma node data includes layout, styling, and hierarchy information that should guide your implementation.
    """
  end
end
