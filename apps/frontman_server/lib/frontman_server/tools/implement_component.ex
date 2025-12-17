defmodule FrontmanServer.Tools.ImplementComponent do
  @moduledoc """
  Spawns a sub-agent to implement a single UI component from Figma design.

  This tool is typically called after a breakdown_figma_node analysis, where
  each component from the breakdown can be implemented by spawning an
  implement_component sub-agent.

  The sub-agent focuses ONLY on implementation (no screenshots or browser navigation):
  1. Fetch the full Figma node data via get_figma_node
  2. Analyze the design and take notes on key details
  3. Implement the component based on the Figma data

  After this tool completes, use `finish_component` to visually verify
  the implementation against the Figma design.
  """

  @behaviour FrontmanServer.Tools.Backend

  require Logger

  alias FrontmanServer.Agents
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

  4. **Return the implementation details** - Your response MUST include:
     - **File paths created**: List ALL files you created or modified
     - **Implementation summary**: A brief summary of what was implemented, key decisions made,
       and patterns used
     - **Design details**: Key details from the Figma design (colors, typography, spacing values)
       that will help verify the implementation

  ## Output Format

  At the end of your response, include a structured summary in this exact format:

  ```
  ## Implementation Complete

  ### Files Created
  - path/to/Component.tsx
  - path/to/styles.css (if applicable)

  ### Implementation Summary
  [Brief description of what was implemented, key decisions, patterns used]

  ### Design Details
  [Key design details from Figma: colors, typography, spacing, etc.]
  ```

  IMPORTANT INSTRUCTIONS:
  - **DO NOT take screenshots or navigate to test pages** - focus ONLY on implementing the component
  - **DO NOT use browser tools** (navigate, take_screenshot, get_errors) - verification happens separately
  - Match the Figma design as precisely as possible based on the Figma node data
  - Write clean, reusable TypeScript React code
  - STRICTLY follow project conventions and research findings from provided documentation
  - Check existing components in the project for reference patterns
  - Do NOT engage in conversation or ask clarifying questions
  - Complete your task and return the implementation details in the specified format
  """

  @impl true
  def name, do: "implement_component"

  @impl true
  def description do
    """
    Implement a single UI component based on Figma design data.

    Use this after breaking down a Figma design to implement each component.
    The tool will spawn a sub-agent that fetches the Figma node, analyzes the design,
    and implements the component.

    After this tool completes, use `finish_component` to visually verify the implementation.
    This tool returns the file paths created and implementation summary needed for verification.
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
          "description" => "The Figma node ID for this component (e.g., '0:1927')"
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
  def execute(args, %Context{task: task, agent_id: parent_agent_id}) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")

    mcp_tools = MCP.to_llm_format(task.mcp_tools)

    Logger.info(
      "ImplementComponent: Starting implementation of #{component_name} (#{node_id}) with #{length(mcp_tools)} MCP tools"
    )

    system_msg = ReqLLM.Context.system(@system_prompt)
    user_msg = build_user_message(args)

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
           parent_agent_id: parent_agent_id
         ) do
      {:ok, result} ->
        Logger.info("ImplementComponent: Completed #{component_name}")

        {:ok,
         %{
           "implementation" => result,
           "componentName" => component_name,
           "nodeId" => node_id
         }}

      {:error, reason} ->
        Logger.error("ImplementComponent: Failed - #{inspect(reason)}")
        {:error, "Implementation failed: #{inspect(reason)}"}
    end
  end

  defp build_user_message(args) do
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

    ## First Step: Fetch the Figma Node

    Use `get_figma_node` with:
    - nodeId: "#{node_id}"
    - includeImage: true
    - withChildren: true
    - embedVectors: true
    - embedImages: true
    #{additional_context_str}

    After fetching, implement the component following your instructions.
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
