defmodule FrontmanServer.Tools.ImplementComponent do
  @moduledoc """
  Spawns a sub-agent to implement a single UI component from Figma design.

  This tool is typically called after a breakdown_figma_design analysis, where
  each component from the breakdown can be implemented by spawning an
  implement_component sub-agent.

  The sub-agent focuses on implementation and test page creation:
  1. Fetch the full Figma node data via get_figma_node
  2. Analyze the design and take notes on key details
  3. Implement the component based on the Figma data
  4. Create a test page to render the component

  After this tool completes, use `fix_files_errors` to fix any runtime errors,
  then `visual_compare_component_to_figma` to assess visual quality, and
  `fix_visual_issues` if there are visual discrepancies to fix.
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
  You are a frontend component implementation specialist. Your task is to implement
  a single UI component based on Figma design data.

  ## Project Context & Conventions

  **CRITICAL:** If you have been provided with project documentation, research findings,
  or convention files (typically loaded as markdown files in your context), you MUST
  take them into account throughout the entire implementation process. These documents
  contain essential information about:
  - Project-specific coding patterns and conventions
  - Technology choices and their rationale
  - Design system guidelines
  - Component structure preferences
  - Research findings about the project
  - Best practices specific to this codebase

  Always prioritize and follow these project-specific guidelines over generic conventions.

  ## Instructions

  1. **Fetch the Figma node** - Use `get_figma_node` with:
     - nodeId: (provided in your task - use WITHOUT the # prefix)
     - includeImage: true
     - withChildren: true
     - embedVectors: true
     - embedImages: true

  2. **Analyze the design** - Study the returned node structure and image to understand:
     - Layout and spacing
     - Typography and colors
     - Interactive states (if any)
     - Responsive behavior hints
     **Take detailed notes** on the key design details (colors, fonts, spacing values, etc.)
     as these will be passed to the verification step.

  3. **Implement the component** - Create a React component that:
     - Matches the Figma design precisely
     - CRITICAL! Follows ALL project conventions and research findings provided in your context
     - Uses TypeScript with proper types
     - Is reusable and well-structured
     - Adheres to the project's design system and component patterns
     - **MUST add the provided `data-test-id` attribute to the top-level/root element** of the component.
       This is required for testing and verification purposes.

  4. **Create a test page** - Create a temporary test page file that renders the component
     in isolation. Import the component from the file path where you created it.

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
     - The test page should ONLY render the component and nothing else
     - Choose a clear test page path like `app/(group)/test-component-name/page.tsx`

  5. **Verify implementation compliance** - Before finalizing, you MUST:
     - Review the source code you've written against ALL project guidelines loaded from:
       - AGENTS.md files (if provided)
       - Project convention documentation (if provided)
       - Research findings and best practices (if provided)
       - Any other markdown documentation files in your context
     - Check that your implementation follows:
       - Coding patterns and conventions specified in the documentation
       - Technology choices and their proper usage
       - Design system guidelines and component structure preferences
       - File organization and naming conventions
       - Import/export patterns
       - Styling approaches (CSS modules, Tailwind, inline styles, etc.)
       - TypeScript/type definitions patterns
     - If you find any discrepancies, **you MUST correct them** before proceeding
     - Ensure the final code is fully compliant with all project-specific guidelines

  6. **Return the implementation details** - Your final response MUST be a valid JSON object.

  ## Output Format

  **CRITICAL:** Your response MUST end with a JSON code block containing the implementation result.
  Format your response like this:

  [Your implementation notes and explanation here...]

  ```json
  {
    "filesCreated": [
      "path/to/Component.tsx",
      "path/to/styles.css",
      "path/to/test-page/page.tsx"
    ],
    "componentFilePath": "path/to/Component.tsx",
    "testPageFilePath": "path/to/test-page/page.tsx",
    "testPageUrl": "/test-component-name",
    "dataTestId": "header-navigation",
    "implementationSummary": "Brief description of what was implemented, key decisions, patterns used",
    "designDetails": "Key design details from Figma: colors, typography, spacing, etc."
  }
  ```

  **JSON Field Requirements:**
  - `filesCreated`: Array of ALL file paths created or modified
  - `componentFilePath`: Path to the main component file
  - `testPageFilePath`: Path to the test page file
  - `testPageUrl`: URL path to navigate to the test page
  - `dataTestId`: The exact data-test-id value on the root element
  - `implementationSummary`: Brief summary of the implementation
  - `designDetails`: Key design details from Figma

  IMPORTANT INSTRUCTIONS:
  - **DO NOT take screenshots or navigate to test pages** - just CREATE the test page, verification happens separately
  - **DO NOT use browser tools** (navigate, take_screenshot, get_errors) - verification happens separately
  - Match the Figma design as precisely as possible based on the Figma node data
  - Write clean, reusable TypeScript React code
  - STRICTLY follow project conventions and research findings from provided documentation
  - Check existing components in the project for reference patterns
  - **CRITICAL: Before finalizing, verify your source code complies with ALL project guidelines** from AGENTS.md and other documentation files loaded in your context
  - Do NOT engage in conversation or ask clarifying questions
  - Complete your task and return the JSON result in the specified format
  """

  @impl true
  def name, do: "implement_component"

  @impl true
  def description do
    """
    Implement a single UI component based on Figma design data.

    Use this after breaking down a Figma design to implement each component.
    The tool will spawn a sub-agent that fetches the Figma node, analyzes the design,
    implements the component, and creates a test page to render it.

    After this tool completes, use `fix_files_errors` to fix any errors, then
    `visual_compare_component_to_figma` to assess visual quality.
    Returns structured result with filesCreated, testPageUrl, componentFilePath, dataTestId.
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "componentName" => %{
          "type" => "string",
          "description" =>
            "A descriptive name for the component (e.g., 'Header Navigation', 'Feature Card')"
        },
        "nodeId" => %{
          "type" => "string",
          "description" => "The Figma node ID for this component"
        },
        "description" => %{
          "type" => "string",
          "description" => "Brief description of what the component does and its purpose"
        },
        "complexity" => %{
          "type" => "integer",
          "description" => "Estimated complexity (1-10) from the breakdown analysis"
        },
        "dependencies" => %{
          "type" => "string",
          "description" =>
            "Components this depends on, or 'None'. Used to understand build order."
        },
        "targetPath" => %{
          "type" => "string",
          "description" =>
            "Optional target file path where the component should be created (e.g., 'components/Header.tsx')"
        },
        "additionalContext" => %{
          "type" => "string",
          "description" => "Any additional context or requirements for this specific component"
        }
      },
      "required" => ["componentName", "nodeId", "description"]
    }
  end

  @impl true
  def execute(args, %Context{task: task, agent_id: parent_agent_id, llm_opts: llm_opts}) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")
    data_test_id = generate_data_test_id(component_name)

    mcp_tools = MCP.to_llm_format(task.mcp_tools)

    Logger.info(
      "ImplementComponent: Starting implementation of #{component_name} (#{node_id}) with #{length(mcp_tools)} MCP tools"
    )

    system_msg = ReqLLM.Context.system(Prompts.tool_selection_guidance() <> @system_prompt)
    user_msg = build_user_message(args, data_test_id)

    # Extract markdown files from read_file tool results (e.g., project conventions,
    # research findings, AGENTS.md files) and add them as user messages.
    # These provide critical project-specific context that the sub-agent MUST follow.
    markdown_messages = extract_markdown_messages_from_task(task.task_id)

    # Build message list: system, markdown files (conventions/research), then user message
    messages = [system_msg | markdown_messages] ++ [user_msg]

    # Execute sub-agent with MCP tools
    case Agents.execute_sub_agent(task.task_id, messages,
           tools: mcp_tools,
           role: "component_implementor",
           parent_agent_id: parent_agent_id,
           spawning_tool_name: name(),
           llm_opts: llm_opts
         ) do
      {:ok, result} ->
        Logger.info("ImplementComponent: Completed #{component_name}")

        # Parse the JSON result from the agent's response
        parsed_result = parse_implementation_result(result, component_name, node_id, data_test_id)

        {:ok, parsed_result}

      {:error, reason} ->
        Logger.error("ImplementComponent: Failed - #{inspect(reason)}")
        {:error, "Implementation failed: #{inspect(reason)}"}
    end
  end

  # Parses the JSON block from the agent's response
  defp parse_implementation_result(result, component_name, node_id, data_test_id) do
    # Try to extract JSON from the result
    case extract_json_from_response(result) do
      {:ok, json_data} ->
        %{
          "componentName" => component_name,
          "nodeId" => node_id,
          "dataTestId" => Map.get(json_data, "dataTestId", data_test_id),
          "filesCreated" => Map.get(json_data, "filesCreated", []),
          "componentFilePath" => Map.get(json_data, "componentFilePath"),
          "testPageFilePath" => Map.get(json_data, "testPageFilePath"),
          "testPageUrl" => Map.get(json_data, "testPageUrl"),
          "implementationSummary" => Map.get(json_data, "implementationSummary", ""),
          "designDetails" => Map.get(json_data, "designDetails", ""),
          "rawResponse" => result
        }

      :error ->
        # Fallback if JSON parsing fails
        Logger.warning("ImplementComponent: Could not parse JSON from response, using raw result")

        %{
          "componentName" => component_name,
          "nodeId" => node_id,
          "dataTestId" => data_test_id,
          "filesCreated" => [],
          "componentFilePath" => nil,
          "testPageFilePath" => nil,
          "testPageUrl" => nil,
          "implementationSummary" => "",
          "designDetails" => "",
          "rawResponse" => result
        }
    end
  end

  # Extracts and parses JSON from markdown code blocks or raw JSON in the response
  defp extract_json_from_response(response) do
    # Try to find JSON in a code block first
    json_block_regex = ~r/```(?:json)?\s*\n?([\s\S]*?)\n?```/

    case Regex.run(json_block_regex, response) do
      [_, json_content] ->
        parse_json(json_content)

      nil ->
        # Try to find raw JSON object
        case Regex.run(~r/\{[\s\S]*"filesCreated"[\s\S]*\}/, response) do
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

  defp build_user_message(args, data_test_id) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")
    description = Map.get(args, "description")
    complexity = Map.get(args, "complexity")
    dependencies = Map.get(args, "dependencies", "None")
    target_path = Map.get(args, "targetPath")
    additional_context = Map.get(args, "additionalContext")

    complexity_str = if complexity, do: "#{complexity}/10", else: "Unknown"
    target_path_str = if target_path, do: "\n- **Target Path:** #{target_path}", else: ""

    additional_context_str =
      if additional_context do
        "\n\n## Additional Context\n\n#{additional_context}"
      else
        ""
      end

    task_text = """
    ## Implement Component

    - **Component:** #{component_name}
    - **Node ID:** #{node_id}
    - **Description:** #{description}
    - **Complexity:** #{complexity_str}
    - **Dependencies:** #{dependencies}#{target_path_str}
    - **Data Test ID:** `#{data_test_id}` (MUST be added to the top-level/root element as `data-test-id="#{data_test_id}"`)

    ## First Step: Fetch the Figma Node

    Use `get_figma_node` with:
    - nodeId: "#{node_id}"
    - includeImage: true
    - withChildren: true
    - embedVectors: true
    - embedImages: true
    #{additional_context_str}

    After fetching, implement the component following your instructions.
    Remember: The top-level element MUST have `data-test-id="#{data_test_id}"`.
    """

    ReqLLM.Context.user(task_text)
  end

  # Generates a kebab-case data-test-id from the component name
  # e.g., "Header Navigation" -> "header-navigation"
  defp generate_data_test_id(component_name) do
    component_name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  # Extracts markdown file contents from read_file ToolResult interactions
  # in the task and converts them to user messages.
  defp extract_markdown_messages_from_task(task_id) do
    task_id
    |> Tasks.get_interactions()
    |> Interaction.extract_markdown_messages()
  end
end
