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

  # Use Claude Sonnet 4 for visual comparison - it has better vision capabilities
  @visual_comparison_model "openrouter:anthropic/claude-sonnet-4"

  @system_prompt """
  You are a meticulous visual comparison specialist. Your task is to compare an implemented
  component against its original Figma design and provide a detailed, actionable assessment.

  ## Your Goal

  Perform a **thorough visual comparison** between the implementation and Figma design.
  Describe both images in detail, identify all differences, and provide clear instructions
  on how to fix them.

  ## Instructions

  1. **Fetch the Figma node** - Use `get_figma_node` with:
     - nodeId: (provided in your task - use WITHOUT the # prefix)
     - includeImage: true
     - withChildren: false (we only need the image for comparison)

  2. **Navigate to test page** - Use `navigate` tool with the test page URL provided

  3. **Take a screenshot** - Use `take_screenshot` tool with the provided CSS selector
     to capture ONLY the component

  4. **Describe both images thoroughly** - Study each image and write a comprehensive description

  5. **Identify all differences** - Compare the two images and list every visual difference

  6. **Write fix instructions** - For each difference, explain exactly how to fix it

  7. **Navigate back** - Use `navigate_back` tool to leave the test page

  8. **Return assessment** - Provide a structured JSON result

  ## What to Look For

  When describing and comparing images, pay attention to:

  **Layout & Positioning:**
  - Element positions relative to each other
  - Horizontal and vertical alignment
  - Container structure and nesting
  - Width and height proportions

  **Spacing:**
  - Padding inside containers
  - Margins between elements
  - Gaps in flex/grid layouts
  - Whitespace distribution

  **Typography:**
  - Font family, size, weight
  - Text color
  - Line height, letter spacing
  - Text alignment

  **Colors & Backgrounds:**
  - Background colors (solid or gradient)
  - Gradient direction and color stops
  - Text colors
  - Border colors

  **Visual Effects:**
  - Border radius (rounded corners)
  - Shadows
  - Borders
  - Opacity

  **Elements:**
  - Missing or extra elements
  - Icon sizes and colors
  - Image dimensions

  ## Output Format

  **CRITICAL:** Your response MUST end with a JSON code block containing the comparison result.

  ```json
  {
    "figmaDesignDescription": "Detailed description of the Figma design image. Describe the overall layout, structure, and visual hierarchy. List all visible elements from top to bottom or left to right. For each element, describe: its position, size (estimate in pixels), colors (with hex values), typography (font weight, size), spacing from other elements, and any visual effects like shadows or rounded corners. Be thorough - this description should paint a complete picture of the design.",

    "implementationDescription": "Detailed description of the implementation screenshot using the same structure as above. Describe what you actually see, not what you expect to see. Note any visual differences you observe compared to the design.",

    "keyDifferences": [
      "Most important difference - describe what's wrong and how it differs from the design",
      "Second difference - be specific about values (e.g., '16px instead of 24px')",
      "Third difference - include color values where relevant",
      "Continue listing all visible differences..."
    ],

    "howToFix": "A comprehensive explanation of how to fix all the visual issues. Start with the most impactful changes first. For each issue, explain:\n\n1. **[Issue name]**: Describe the problem and the exact CSS/code change needed. Example: 'The container is missing its gradient background. Add `background: linear-gradient(135deg, #667eea 0%, #764ba2 100%)` to the root element.'\n\n2. **[Next issue]**: Continue with specific, actionable instructions...\n\nGroup related fixes together (e.g., all spacing fixes, all typography fixes). Include exact CSS property names and values. If a fix affects multiple properties, list them all."
  }
  ```

  **Field Requirements:**

  - `figmaDesignDescription`: A comprehensive, detailed description of the Figma design image.
    Write as if describing the image to someone who cannot see it. Include:
    - Overall structure and layout
    - All visible elements and their positions
    - Colors with hex values
    - Typography details (weight, size estimates)
    - Spacing estimates in pixels
    - Visual effects (shadows, gradients, rounded corners)

  - `implementationDescription`: An equally detailed description of the implementation screenshot.
    Use the same structure to make comparison easy. Describe what you actually see.

  - `keyDifferences`: An array of strings listing every visual difference between the two images.
    Order from most impactful to least. Be specific with values.

  - `howToFix`: A single comprehensive string explaining how to fix ALL issues.
    This should read like a step-by-step guide. Include exact CSS properties and values.
    Group related fixes together. Start with the most impactful changes.

  ## Writing Guidelines

  **For descriptions:**
  - Be thorough and specific
  - Include measurements (estimate in pixels)
  - Use hex color values when possible
  - Describe spatial relationships

  **For differences:**
  - Start with "The [element]..." or similar
  - Include both the current and expected values
  - Be specific: "padding is 16px, should be 24px"

  **For fix instructions:**
  - Use exact CSS property names
  - Include complete values
  - Explain the reasoning when helpful
  - Group related changes together

  IMPORTANT INSTRUCTIONS:
  - ALWAYS start by describing both images in detail
  - Be extremely thorough - catching issues now saves iteration later
  - Focus on what IS different, not what matches
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
    detailed descriptions of both images, their differences, and how to fix them.

    Returns: figmaDesignDescription, implementationDescription, keyDifferences, howToFix
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
      "VisualCompareComponentToFigma: Starting comparison for #{component_name} (#{node_id}) using model #{@visual_comparison_model}"
    )

    system_msg = ReqLLM.Context.system(Prompts.tool_selection_guidance() <> @system_prompt)
    user_msg = build_user_message(args)

    # Extract markdown files from read_file tool results
    markdown_messages = extract_markdown_messages_from_task(task.task_id)

    # Build message list
    messages = [system_msg | markdown_messages] ++ [user_msg]

    # Use Claude Sonnet 4 for visual comparison - override the model in llm_opts
    visual_llm_opts = Keyword.put(llm_opts, :model, @visual_comparison_model)

    # Execute sub-agent with MCP tools and custom model
    case Agents.execute_sub_agent(task.task_id, messages,
           tools: mcp_tools,
           role: "visual_comparator",
           parent_agent_id: parent_agent_id,
           spawning_tool_name: name(),
           llm_opts: visual_llm_opts
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
          "figmaDesignDescription" => Map.get(json_data, "figmaDesignDescription", ""),
          "implementationDescription" => Map.get(json_data, "implementationDescription", ""),
          "keyDifferences" => Map.get(json_data, "keyDifferences", []),
          "howToFix" => Map.get(json_data, "howToFix", ""),
          "rawResponse" => result
        }

      :error ->
        Logger.warning("VisualCompareComponentToFigma: Could not parse JSON from response")

        %{
          "componentName" => component_name,
          "nodeId" => node_id,
          "figmaDesignDescription" => "",
          "implementationDescription" => "",
          "keyDifferences" => ["Could not parse comparison result"],
          "howToFix" => result,
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
        # Try to find JSON with our expected fields
        case Regex.run(~r/\{[\s\S]*"figmaDesignDescription"[\s\S]*\}/, response) do
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
