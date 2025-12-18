defmodule FrontmanServer.Tools.ImplementComponent do
  @moduledoc """
  Spawns a sub-agent to implement a single UI component from Figma design.
  """

  @behaviour FrontmanServer.Tools.Backend

  require Logger

  alias FrontmanServer.Agents
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.MCP

  @system_prompt """
  You are a frontend component implementation specialist. Your task is to implement
  a single UI component based on Figma design data.

  ## Instructions

  1. **Fetch the Figma node** - Use `get_figma_node` with:
     - nodeId: (provided in your task)
     - includeImage: true
     - withChildren: true
     - embedVectors: true
     - embedImages: true

  2. **Analyze the design** - Study the returned node structure and image to understand:
     - Layout and spacing
     - Typography and colors
     - Interactive states (if any)
     - Responsive behavior hints

  3. **Implement the component** - Create a React component that:
     - Matches the Figma design precisely
     - Uses Tailwind CSS for styling
     - Follows project conventions (TypeScript, proper types)
     - Is reusable and well-structured

  4. **Verify the implementation** - Visual verification loop:
     a. **Create a test page** - Create a temporary test page file that renders your component in isolation
     b. **Navigate to test page** - Use `navigate` tool with a relative URL to the test page
     c. **Check for errors** - Use `get_errors` tool to check for errors, iterate if needed
     d. **Take a screenshot** - Use `take_screenshot` tool to capture how the component renders
     e. **Compare with Figma** - Compare the screenshot against the original Figma design image
     f. **Iterate if needed** - If the implementation doesn't match, fix and retry
     g. **Navigate back** - Once verified, use `navigate_back` tool
     h. **Clean up** - Delete the temporary test page file

  5. **Return the implementation** - Provide the complete, verified component code

  IMPORTANT INSTRUCTIONS:
  - ONLY SHOW THE COMPONENT AND NOTHING ELSE ON THE TEST PAGE
  - Match the Figma design as precisely as possible
  - Write clean, reusable TypeScript React code
  - Follow project conventions (check existing components if available)
  - Do NOT engage in conversation or ask clarifying questions
  - Complete your task and return the implementation code
  """

  @impl true
  def name, do: "implement_component"

  @impl true
  def description do
    """
    Implement a single UI component based on Figma design data.

    Use this after breaking down a Figma design to implement each component.
    The tool will spawn a sub-agent that has access to browser tools for
    visual verification.
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

    system_msg = ReqLLM.Context.system(@system_prompt, cache_control: %{type: "ephemeral"})
    user_msg = build_user_message(args)

    case Agents.execute_sub_agent(task.id, [system_msg, user_msg],
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
end
