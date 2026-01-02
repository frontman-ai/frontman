defmodule FrontmanServer.Tools.VisualCompareComponentToFigma do
  @moduledoc """
  Spawns a sub-agent to compare the implemented component against the Figma design.

  This tool is called after fix_files_errors completes. It takes the Figma node ID,
  test page URL, and component path, then performs a visual comparison.

  The sub-agent:
  1. Fetches the Figma node image
  2. Navigates to the test page
  3. Takes a screenshot of the component
  4. Compares the two images and reports discrepancies

  Returns a structured result with match quality and specific visual differences.
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
  You are a meticulous visual comparison specialist. Your task is to compare an implemented
  component against its original Figma design and provide a detailed, actionable assessment.

  ## Your Goal

  Perform a **pixel-level visual comparison** between the implementation and Figma design.
  Your assessment must be thorough and catch all visual discrepancies, especially focusing
  on element positioning and spatial relationships.

  ## Instructions

  1. **Fetch the Figma node** - Use `get_figma_node` with:
     - nodeId: (provided in your task - use WITHOUT the # prefix)
     - includeImage: true
     - withChildren: false (we only need the image for comparison)

  2. **Navigate to test page** - Use `navigate` tool with the test page URL provided

  3. **Take a screenshot** - Use `take_screenshot` tool with the provided CSS selector
     to capture ONLY the component

  4. **Perform detailed comparison** - Follow the comprehensive checklist below

  5. **Navigate back** - Use `navigate_back` tool to leave the test page

  6. **Return assessment** - Provide a structured JSON result with specific, actionable issues

  ## CRITICAL: Comprehensive Visual Comparison Checklist

  ### 1. ELEMENT POSITIONING & SPATIAL RELATIONSHIPS (Most Important!)

  **Relative Positioning Between Elements:**
  - Are elements positioned correctly relative to EACH OTHER?
  - Check horizontal alignment: Are elements that should be on the same horizontal line aligned?
  - Check vertical alignment: Are elements that should be on the same vertical line aligned?
  - Compare distances BETWEEN elements (not just within them)
  - Check if elements maintain correct relative positions (left-of, right-of, above, below)

  **Edge Alignment & Boundaries:**
  - Do left edges of elements align where they should?
  - Do right edges of elements align where they should?
  - Do top edges of elements align where they should?
  - Do bottom edges of elements align where they should?
  - Are elements properly contained within their parent boundaries?

  **Proportional Relationships:**
  - Are width ratios between elements correct? (e.g., sidebar should be 1/3 of container)
  - Are height ratios between elements correct?
  - Do elements maintain correct aspect ratios?

  ### 2. SPACING & GAPS

  **Internal Spacing (Padding):**
  - Top padding within containers
  - Bottom padding within containers
  - Left padding within containers
  - Right padding within containers

  **External Spacing (Margins/Gaps):**
  - Horizontal gaps between sibling elements
  - Vertical gaps between stacked elements
  - Spacing from parent container edges
  - Consistent spacing patterns (e.g., all cards should have same gap)

  **Negative Space:**
  - Is whitespace distributed correctly?
  - Are empty areas the right size?

  ### 3. LAYOUT STRUCTURE

  **Flex/Grid Behavior:**
  - Is the layout direction correct (row vs column)?
  - Is content distribution correct (space-between, center, etc.)?
  - Do elements wrap correctly?
  - Is alignment on cross-axis correct?

  **Container Sizing:**
  - Are container widths correct?
  - Are container heights correct?
  - Do containers grow/shrink appropriately?

  ### 4. TYPOGRAPHY

  **Text Properties:**
  - Font family (is it the correct font?)
  - Font size (compare visually - is text same size?)
  - Font weight (bold, medium, regular?)
  - Line height (spacing between text lines)
  - Letter spacing (tracking)
  - Text color

  **Text Layout:**
  - Text alignment (left, center, right, justify)
  - Text truncation/overflow behavior
  - Multi-line text wrapping

  ### 5. COLORS & VISUAL STYLING

  **CRITICAL - Backgrounds (Missing backgrounds = CRITICAL ISSUE!):**
  - Is there a background color? If Figma shows one and implementation doesn't, this is CRITICAL
  - Is there a gradient background? Gradient backgrounds are often missed - check carefully!
  - Does the gradient direction match (linear-gradient angle, radial-gradient position)?
  - Are gradient color stops correct (colors and positions)?
  - Is the background applied to the correct element (not a parent or child)?
  - **A missing background or gradient is a CRITICAL issue that breaks the design**

  **Colors:**
  - Background colors (exact match?)
  - Text colors
  - Border colors
  - Icon/SVG fill colors

  **Effects:**
  - Box shadows (size, blur, color, offset)
  - Border radius (corner rounding)
  - Border width and style
  - Opacity/transparency

  ### 6. ELEMENTS & CONTENT

  **Presence Check:**
  - Are all elements from the design present?
  - Are there any extra elements not in the design?
  - Are icons/images correct?

  **Element Sizing:**
  - Are icons the right size?
  - Are images the right dimensions?
  - Are buttons the right size?

  ## Output Format

  **CRITICAL:** Your response MUST end with a JSON code block containing the comparison result.

  ```json
  {
    "matchQuality": "fair",
    "overallScore": 65,
    "categories": {
      "positioning": {
        "score": 80,
        "issues": [
          "Button is 8px too far right relative to the title",
          "Icon is not vertically centered with text - appears 2px too high",
          "Cards are not aligned - second card's left edge is 4px off from first"
        ]
      },
      "spacing": {
        "score": 75,
        "issues": [
          "Gap between title and description is 16px, should be 24px",
          "Container has 12px padding, design shows 20px",
          "Horizontal gap between buttons is 8px, should be 12px"
        ]
      },
      "layout": {
        "score": 90,
        "issues": ["Content is not centered within container"]
      },
      "typography": {
        "score": 85,
        "issues": [
          "Title font weight is 500, should be 600",
          "Body text line-height appears tighter than design"
        ]
      },
      "backgrounds": {
        "score": 0,
        "issues": [
          "MISSING gradient background - Figma shows linear-gradient(135deg, #667eea 0%, #764ba2 100%) but implementation has no background",
          "Card has white background in Figma but implementation shows transparent"
        ]
      },
      "colors": {
        "score": 95,
        "issues": ["Border color is #E5E5E5, design shows #D1D5DB"]
      },
      "elements": {
        "score": 100,
        "issues": []
      }
    },
    "criticalIssues": [
      "MISSING gradient background - Figma shows linear-gradient(135deg, #667eea 0%, #764ba2 100%) but implementation has no background",
      "Card has white background in Figma but implementation shows transparent"
    ],
    "minorIssues": [
      "Icon is not vertically centered with text - appears 2px too high",
      "Border color is #E5E5E5, design shows #D1D5DB"
    ],
    "summary": "CRITICAL: Missing gradient background completely changes the look. Layout structure is mostly correct but the missing background is a major issue that must be fixed."
  }
  ```

  **JSON Field Requirements:**
  - `matchQuality`: One of "excellent" (90+), "good" (70-89), "fair" (50-69), "poor" (<50)
  - `overallScore`: Number 0-100 representing overall visual match
  - `categories`: Object with scores and issues for each visual category
    - `positioning`: Element positions relative to each other, alignment, boundaries
    - `spacing`: Padding, margins, gaps between and around elements
    - `layout`: Overall structure, flex/grid behavior, container sizing
    - `typography`: Fonts, sizes, weights, text styling
    - `backgrounds`: Background colors and gradients (CRITICAL - missing = score 0)
    - `colors`: Text colors, border colors, shadows
    - `elements`: Missing/extra elements, icons, images
  - `criticalIssues`: Issues that make the component look noticeably different from design
    - **Missing backgrounds or gradients are ALWAYS critical issues**
  - `minorIssues`: Small discrepancies that are visible but don't break the design
  - `summary`: Brief overall assessment with the main problems highlighted

  ## Issue Writing Guidelines

  **BE SPECIFIC AND ACTIONABLE:**
  - BAD: "Spacing is wrong"
  - GOOD: "Gap between header and content is 16px, should be 32px"

  - BAD: "Button is misaligned"
  - GOOD: "Button's right edge should align with card's right edge, currently 12px short"

  - BAD: "Text looks different"
  - GOOD: "Title font-weight is 400 (regular), design shows 600 (semi-bold)"

  **INCLUDE MEASUREMENTS WHEN POSSIBLE:**
  - Estimate pixel values based on visual comparison
  - Reference specific elements by name/description
  - Describe spatial relationships clearly

  IMPORTANT INSTRUCTIONS:
  - Be extremely thorough - catching issues now saves iteration later
  - Focus especially on POSITIONING and SPATIAL RELATIONSHIPS between elements
  - Check alignment both within elements AND across element boundaries
  - Be specific and actionable in your issue descriptions
  - Do NOT engage in conversation or ask clarifying questions
  - Do NOT make any code changes - just assess and report
  - **ALWAYS use `navigate_back` before returning** to leave the test page
  - Complete your task and return the JSON result
  """

  @impl true
  def name, do: "visual_compare_component_to_figma"

  @impl true
  def description do
    """
    Compare an implemented component against its Figma design.

    Use this after fix_files_errors to verify the visual accuracy of the implementation.
    The tool fetches the Figma design, takes a screenshot of the component, and provides
    a structured assessment of how well they match.

    Returns a detailed comparison result with scores and specific issues to fix.
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "componentName" => %{
          "type" => "string",
          "description" => "Name of the component being compared"
        },
        "nodeId" => %{
          "type" => "string",
          "description" => "The Figma node ID to compare against WITHOUT the # prefix"
        },
        "testPageUrl" => %{
          "type" => "string",
          "description" => "The URL path to navigate to the test page"
        },
        "componentFilePath" => %{
          "type" => "string",
          "description" => "Path to the main component file"
        },
        "dataTestId" => %{
          "type" => "string",
          "description" => "The data-test-id value used on the component's root element"
        }
      },
      "required" => ["componentName", "nodeId", "testPageUrl", "dataTestId"]
    }
  end

  @impl true
  def execute(args, %Context{task: task, agent_id: parent_agent_id, llm_opts: llm_opts}) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")

    mcp_tools = MCP.to_llm_format(task.mcp_tools)

    Logger.info(
      "VisualCompareComponentToFigma: Starting comparison for #{component_name} (#{node_id})"
    )

    system_msg = ReqLLM.Context.system(Prompts.tool_selection_guidance() <> @system_prompt)
    user_msg = build_user_message(args)

    # Extract markdown files from read_file tool results
    markdown_messages = extract_markdown_messages_from_task(task.task_id)

    # Build message list
    messages = [system_msg | markdown_messages] ++ [user_msg]

    # Execute sub-agent with MCP tools
    case Agents.execute_sub_agent(task.task_id, messages,
           tools: mcp_tools,
           role: "visual_comparator",
           parent_agent_id: parent_agent_id,
           spawning_tool_name: name(),
           llm_opts: llm_opts
         ) do
      {:ok, result} ->
        Logger.info("VisualCompareComponentToFigma: Completed comparison for #{component_name}")

        parsed_result = parse_comparison_result(result, component_name, node_id)
        {:ok, parsed_result}

      {:error, reason} ->
        Logger.error("VisualCompareComponentToFigma: Failed - #{inspect(reason)}")
        {:error, "Comparison failed: #{inspect(reason)}"}
    end
  end

  defp build_user_message(args) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")
    test_page_url = Map.get(args, "testPageUrl")
    component_file_path = Map.get(args, "componentFilePath")
    data_test_id = Map.get(args, "dataTestId")

    selector_str = if data_test_id, do: "[data-test-id=\"#{data_test_id}\"]", else: nil

    component_path_str =
      if component_file_path,
        do: "\n- **Component File:** #{component_file_path}",
        else: ""

    selector_instruction =
      if selector_str do
        "\n- **Selector:** `#{selector_str}` (Use this with `take_screenshot` to capture ONLY the component)"
      else
        ""
      end

    task_text = """
    ## Compare Component Implementation

    - **Component:** #{component_name}
    - **Node ID:** #{node_id}
    - **Test Page URL:** #{test_page_url}
    - **Data Test ID:** `#{data_test_id}`#{selector_instruction}#{component_path_str}

    ## First Step: Fetch the Figma Node

    Use `get_figma_node` with:
    - nodeId: "#{node_id}"
    - includeImage: true
    - withChildren: false

    After fetching, navigate to `#{test_page_url}` and take a screenshot using the selector.
    Then compare both images and provide your assessment.
    """

    ReqLLM.Context.user(task_text)
  end

  # Parses the JSON block from the agent's response
  defp parse_comparison_result(result, component_name, node_id) do
    case extract_json_from_response(result) do
      {:ok, json_data} ->
        %{
          "componentName" => component_name,
          "nodeId" => node_id,
          "matchQuality" => Map.get(json_data, "matchQuality", "unknown"),
          "overallScore" => Map.get(json_data, "overallScore", 0),
          "categories" => Map.get(json_data, "categories", %{}),
          "criticalIssues" => Map.get(json_data, "criticalIssues", []),
          "minorIssues" => Map.get(json_data, "minorIssues", []),
          "summary" => Map.get(json_data, "summary", ""),
          "rawResponse" => result
        }

      :error ->
        Logger.warning("VisualCompareComponentToFigma: Could not parse JSON from response")

        %{
          "componentName" => component_name,
          "nodeId" => node_id,
          "matchQuality" => "unknown",
          "overallScore" => 0,
          "categories" => %{},
          "criticalIssues" => ["Could not parse comparison result"],
          "minorIssues" => [],
          "summary" => result,
          "rawResponse" => result
        }
    end
  end

  defp extract_json_from_response(response) do
    json_block_regex = ~r/```(?:json)?\s*\n?([\s\S]*?)\n?```/

    case Regex.run(json_block_regex, response) do
      [_, json_content] ->
        parse_json(json_content)

      nil ->
        case Regex.run(~r/\{[\s\S]*"matchQuality"[\s\S]*\}/, response) do
          [json_content] -> parse_json(json_content)
          nil -> :error
        end
    end
  end

  defp parse_json(json_string) do
    case Jason.decode(String.trim(json_string)) do
      {:ok, data} when is_map(data) -> {:ok, data}
      _ -> :error
    end
  end

  defp extract_markdown_messages_from_task(task_id) do
    task_id
    |> Tasks.get_interactions()
    |> Interaction.extract_markdown_messages()
  end
end
