defmodule FrontmanServer.Tools.FinishComponent do
  @moduledoc """
  Spawns a sub-agent to verify and finish a component implementation.

  This tool is called after implement_component completes. It takes the implementation
  results (file paths, test page URL, summary) and performs visual verification against the Figma design.

  The sub-agent:
  1. Navigates to the test page created by implement_component
  2. Takes screenshots and compares with the Figma design
  3. Makes adjustments until the component roughly matches the design
  4. Cleans up the test page and reports completion

  Note: The verification aims for a close match, not pixel-perfect accuracy.
  """

  @behaviour FrontmanServer.Tools.Backend

  require Logger

  alias FrontmanServer.Agents
  alias FrontmanServer.Agents.Prompts
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.MCP

  @system_prompt """
  You are a frontend component verification specialist. Your task is to verify and finish
  a component implementation by comparing it visually against the original Figma design.

  ## Project Context & Conventions

  **CRITICAL:** If you have been provided with project documentation, research findings,
  or convention files, you MUST follow them throughout the verification process.

  ## Your Goal

  Verify that the implemented component **roughly matches** the Figma design. You are NOT
  aiming for pixel-perfect accuracy - instead, ensure:
  - Overall layout and structure match
  - Colors and typography are approximately correct
  - Spacing and proportions are reasonable
  - Interactive elements are in the right positions
  - The component is visually acceptable for the intended use

  ## Instructions

  1. **Fetch the Figma node** - Use `get_figma_node` with:
     - nodeId: (provided in your task - use WITHOUT the # prefix)
     - includeImage: true
     - withChildren: false (we only need the image for comparison)

  2. **Navigate to test page** - Use `navigate` tool with the test page URL provided in your task

  3. **Check for errors** - Use `get_errors` tool to check for errors. Fix any errors found.

  4. **Visual verification loop**:
     a. **Take a screenshot** - Use `take_screenshot` tool to capture the rendered component.
        If a CSS selector (e.g., `[data-test-id="..."]`) is provided in your task, use it with the `selector` parameter
        of `take_screenshot` to capture ONLY the component.
     b. **Compare with Figma** - Compare the screenshot against the Figma design image
     c. **Assess the match** - Determine if the implementation roughly matches:
        - If YES: Proceed to the final audit
        - If NO: Make targeted fixes and repeat the loop (max 3 iterations)

  5. **Final Page Audit** - After completing the verification loop:
     a. **Check for errors again** - Use `get_errors` tool to ensure no runtime errors occurred during rendering or interaction.
     b. **Take a full-page screenshot** - Use `take_screenshot` tool WITHOUT a selector to capture the entire page. Verify the component is correctly positioned and no error overlays or blocking elements are present.

  6. **Cleanup and complete**:
     a. Use `navigate_back` tool to leave the test page
     b. Delete the test page file (path provided in your task)
     c. Report your findings

  ## Important Guidelines

  - The test page was already created by implement_component - just navigate to it
  - Focus on structural and visual correctness, not pixel-perfect matching
  - Make minimal, targeted fixes - don't refactor or over-engineer
  - After 3 verification iterations, accept the current state if reasonably close
  - Do NOT engage in conversation or ask clarifying questions
  - Complete your task and return the verification result
  """

  @impl true
  def name, do: "finish_component"

  @impl true
  def description do
    """
    Verify and finish a component implementation by comparing it visually against the Figma design.

    Use this after implement_component completes to verify the implementation matches
    the original design. The tool will navigate to the test page created by implement_component,
    take screenshots, and compare against the Figma design, making adjustments if needed.

    The verification aims for a close match, not pixel-perfect accuracy.
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "componentName" => %{
          "type" => "string",
          "description" => "Name of the component being verified"
        },
        "nodeId" => %{
          "type" => "string",
          "description" => "The Figma node ID to compare against WITHOUT the # prefix"
        },
        "filePaths" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "List of file paths created by the implementation (including component and test page)"
        },
        "testPageFilePath" => %{
          "type" => "string",
          "description" => "The file path to the test page created by implement_component"
        },
        "testPageUrl" => %{
          "type" => "string",
          "description" => "The URL path to navigate to the test page (e.g., '/test-component-name')"
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
        "testPageFilePath",
        "testPageUrl",
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
      "FinishComponent: Starting verification of #{component_name} (#{node_id}) with #{length(mcp_tools)} MCP tools"
    )

    system_msg = ReqLLM.Context.system(Prompts.tool_selection_guidance() <> @system_prompt)
    user_msg = build_user_message(args)

    # Extract markdown files from read_file tool results (e.g., project conventions,
    # research findings, AGENTS.md files) and add them as user messages.
    markdown_messages = extract_markdown_messages_from_task(task.task_id)

    # Build message list: system, markdown files (conventions/research), then user message
    messages = [system_msg | markdown_messages] ++ [user_msg]

    # Execute sub-agent with MCP tools
    case Agents.execute_sub_agent(task.task_id, messages,
           tools: mcp_tools,
           role: "component_finisher",
           parent_agent_id: parent_agent_id,
           spawning_tool_name: name()
         ) do
      {:ok, result} ->
        Logger.info("FinishComponent: Completed verification of #{component_name}")

        {:ok,
         %{
           "verificationResult" => result,
           "componentName" => component_name,
           "nodeId" => node_id,
           "status" => "verified"
         }}

      {:error, reason} ->
        Logger.error("FinishComponent: Failed - #{inspect(reason)}")
        {:error, "Verification failed: #{inspect(reason)}"}
    end
  end

  defp build_user_message(args) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")
    file_paths = Map.get(args, "filePaths", [])
    test_page_file_path = Map.get(args, "testPageFilePath")
    test_page_url = Map.get(args, "testPageUrl")
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
    ## Verify Component Implementation

    - **Component:** #{component_name}
    - **Node ID:** #{node_id}
    - **Data Test ID:** `#{data_test_id || "None"}`#{selector_instruction}
    - **Test Page File Path:** #{test_page_file_path}
    - **Test Page URL:** #{test_page_url}

    ## Files Created

    #{file_paths_str}

    ## Implementation Summary

    #{implementation_summary}
    #{design_details_str}
    ## First Step: Fetch the Figma Node

    Use `get_figma_node` with:
    - nodeId: "#{node_id}"
    - includeImage: true
    - withChildren: false

    After fetching, navigate to the test page at `#{test_page_url}` and begin the visual verification process.
    Remember to delete the test page file at `#{test_page_file_path}` when you're done.
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
