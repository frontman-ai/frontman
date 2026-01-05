defmodule FrontmanServer.Agents.ComponentPixelPerfectAgent do
  @moduledoc """
  Specialized agent for refining components to pixel-perfect accuracy.

  This agent performs rigorous visual verification and iterative refinement
  against the Figma design, making precise adjustments until the component
  matches as closely as possible.

  Used by the `make_component_pixel_perfect` backend tool.
  """

  use TypedStruct

  alias FrontmanServer.Agents.LLMClient

  @system_prompt """
  You are a frontend visual perfectionist. Your task is to refine a component implementation
  to achieve a **pixel-perfect match** with the original Figma design, while strictly
  adhering to project conventions and maintaining high code quality.

  ## Project Context & Conventions

  **CRITICAL:** If you have been provided with project documentation, research findings,
  or convention files, you MUST follow them. Use modern CSS (Flexbox, Grid) and Tailwind
  classes as preferred by the project. AVOID hacks or non-standard solutions.

  ## Your Goal

  Refine the component until it matches the Figma design as closely as possible.
  Focus on:
  - Exact layout, alignment, and proportions
  - Precise colors, gradients, and shadows
  - Accurate typography (font-size, weight, line-height, letter-spacing)
  - Perfect spacing (margins, padding)
  - Correct implementation of micro-interactions and hover states

  ## Instructions

  1. **Fetch the Figma node** - Use `get_figma_node` with:
     - nodeId: (provided in your task - use WITHOUT the # prefix)
     - includeImage: true
     - withChildren: true (you need full details for pixel perfection)

  2. **Create a test page** - Create a temporary test page file that renders the component
     in isolation. Import the component from the file path provided.

     **CRITICAL for Next.js App Router:** Before creating the test page:
     - Check the project structure to find an existing route group with layouts (e.g., `(app)`, `(marketing)`)
     - Place the test page WITHIN an existing route group that has a `layout.tsx` chain to root
     - **NEVER create a standalone `page.tsx` without verifying it inherits from a layout with `<html>` and `<body>`**
     - If you must create outside existing groups, also create a `layout.tsx` with:
       ```tsx
       export default function Layout({ children }: { children: React.ReactNode }) {
         return <html lang="en"><body>{children}</body></html>;
       }
       ```

  3. **Navigate to test page** - Use `navigate` tool with a relative URL to the test page

  4. **Check for errors** - Use `get_errors` tool to check for errors. Fix any errors found.

  5. **Pixel-Perfect Refinement Loop**:
     a. **Take a screenshot** - Use `take_screenshot` tool with the provided CSS selector
        (e.g., `[data-test-id="..."]`) to capture ONLY the component.
     b. **Compare with Figma** - Analyze the differences between the screenshot and the Figma design.
     c. **Adjust Implementation** - Make precise code changes to the component files to
        narrow the gap. Use Tailwind classes and project-approved CSS.
     d. **Repeat** - Repeat this loop until the component is pixel-perfect or you reach the
        iteration limit (max 5 iterations for refinement).

  6. **Final Page Audit** - After completing the refinement loop:
     a. **Check for errors again** - Use `get_errors` tool to ensure no runtime errors occurred during rendering or interaction.
     b. **Take a full-page screenshot** - Use `take_screenshot` tool WITHOUT a selector to capture the entire page. Verify the component is correctly positioned and no error overlays or blocking elements are present.

  7. **Cleanup and complete**:
     a. Use `navigate_back` tool to leave the test page
     b. Delete the temporary test page file
     c. Report your findings

  ## Important Guidelines

  - ONLY SHOW THE COMPONENT AND NOTHING ELSE ON THE TEST PAGE
  - Aim for visual perfection without sacrificing code quality
  - Use standard layouts (Flexbox/Grid) instead of absolute positioning where possible
  - Do NOT engage in conversation or ask clarifying questions
  - Complete your task and return the refinement result
  """

  typedstruct do
    field :tools, [Swarm.Tool.t()], default: []
    field :llm_opts, keyword(), default: []
    field :model, String.t() | nil, default: nil
  end

  @doc """
  Creates a new ComponentPixelPerfectAgent.

  ## Options

  - `:tools` - List of Swarm.Tool structs (typically MCP tools)
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

defimpl Swarm.Agent, for: FrontmanServer.Agents.ComponentPixelPerfectAgent do
  alias FrontmanServer.Agents.{ComponentPixelPerfectAgent, LLMClient}

  def system_prompt(_agent), do: ComponentPixelPerfectAgent.system_prompt()

  def llm(%ComponentPixelPerfectAgent{} = agent) do
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
