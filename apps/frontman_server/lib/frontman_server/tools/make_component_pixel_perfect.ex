defmodule FrontmanServer.Tools.MakeComponentPixelPerfect do
  @moduledoc """
  Spawns a sub-agent to refine a component implementation to be pixel-perfect.

  This tool is called when a high degree of visual accuracy is required. It takes the implementation
  results and performs rigorous visual verification and iterative refinement against the Figma design.

  The sub-agent:
  1. Creates a test page to render the component in isolation
  2. Takes screenshots of the component using a specific CSS selector
  3. Compares the screenshot with the Figma design node
  4. Makes precise code adjustments to match the design (layout, colors, typography, spacing)
  5. Repeats the loop (up to 5 times) until the component is pixel-perfect
  6. Ensures code follows project guidelines and avoids hacks

  The verification aims for the highest possible visual fidelity.
  """

  @behaviour FrontmanServer.Tools.Backend

  require Logger

  alias FrontmanServer.Agents
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.MCP

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

  @impl true
  def name, do: "make_component_pixel_perfect"

  @impl true
  def description do
    """
    Refine a component implementation to be pixel-perfect by comparing it visually against the Figma design.

    Use this when a high degree of visual accuracy is required. The tool will create a test page,
    take screenshots using a specific selector, and compare against the Figma design node,
    making precise adjustments until the component matches perfectly.

    The process is iterative and focused on layout, colors, typography, and spacing.
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "componentName" => %{
          "type" => "string",
          "description" => "Name of the component being refined"
        },
        "nodeId" => %{
          "type" => "string",
          "description" => "The Figma node ID to compare against WITHOUT the # prefix"
        },
        "filePaths" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "List of file paths for the component implementation"
        },
        "implementationSummary" => %{
          "type" => "string",
          "description" =>
            "Summary of what was implemented, including key decisions and patterns used"
        },
        "designDetails" => %{
          "type" => "string",
          "description" =>
            "Key details learned from analyzing the Figma design (colors, typography, spacing, etc.)"
        },
        "dataTestId" => %{
          "type" => "string",
          "description" => "The data-test-id value used on the component's root element"
        }
      },
      "required" => [
        "componentName",
        "nodeId",
        "filePaths",
        "implementationSummary",
        "dataTestId"
      ]
    }
  end

  @impl true
  def execute(args, %Context{task: task, agent_id: parent_agent_id}) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")

    mcp_tools = MCP.to_llm_format(task.mcp_tools)

    Logger.info(
      "MakeComponentPixelPerfect: Starting refinement of #{component_name} (#{node_id}) with #{length(mcp_tools)} MCP tools"
    )

    system_msg = ReqLLM.Context.system(@system_prompt)
    user_msg = build_user_message(args)

    # Extract markdown files from read_file tool results (e.g., project conventions,
    # research findings, AGENTS.md files) and add them as user messages.
    markdown_messages = extract_markdown_messages_from_task(task.task_id)

    # Build message list: system, markdown files (conventions/research), then user message
    messages = [system_msg | markdown_messages] ++ [user_msg]

    # Execute sub-agent with MCP tools
    case Agents.execute_sub_agent(task.task_id, messages,
           tools: mcp_tools,
           role: "pixel_perfectionist",
           parent_agent_id: parent_agent_id,
           spawning_tool_name: name()
         ) do
      {:ok, result} ->
        Logger.info("MakeComponentPixelPerfect: Completed refinement of #{component_name}")

        {:ok,
         %{
           "refinementResult" => result,
           "componentName" => component_name,
           "nodeId" => node_id,
           "status" => "pixel-perfect"
         }}

      {:error, reason} ->
        Logger.error("MakeComponentPixelPerfect: Failed - #{inspect(reason)}")
        {:error, "Refinement failed: #{inspect(reason)}"}
    end
  end

  defp build_user_message(args) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")
    file_paths = Map.get(args, "filePaths", [])
    implementation_summary = Map.get(args, "implementationSummary", "")
    design_details = Map.get(args, "designDetails")
    data_test_id = Map.get(args, "dataTestId")

    selector_str = if data_test_id, do: "[data-test-id=\"#{data_test_id}\"]", else: nil

    file_paths_str =
      file_paths
      |> Enum.map(&"  - #{&1}")
      |> Enum.join("\n")

    design_details_str =
      if design_details do
        """

        ## Design Details

        #{design_details}
        """
      else
        ""
      end

    selector_instruction =
      if selector_str do
        "\n- **Selector:** `#{selector_str}` (Use this with `take_screenshot` to capture ONLY the component)"
      else
        ""
      end

    task_text = """
    ## Refine Component to Pixel-Perfect

    - **Component:** #{component_name}
    - **Node ID:** #{node_id}
    - **Data Test ID:** `#{data_test_id || "None"}`#{selector_instruction}

    ## Files to Refine

    #{file_paths_str}

    ## Implementation Summary

    #{implementation_summary}
    #{design_details_str}
    ## First Step: Fetch the Figma Node

    Use `get_figma_node` with:
    - nodeId: "#{node_id}"
    - includeImage: true
    - withChildren: true

    After fetching, create a test page and begin the pixel-perfect refinement process.
    """

    ReqLLM.Context.user(task_text)
  end

  # Extracts markdown file contents from read_file ToolResult interactions
  # in the task and converts them to user messages.
  defp extract_markdown_messages_from_task(task_id) do
    task_id
    |> Tasks.get_interactions()
    |> Interaction.extract_markdown_messages()
  end
end
