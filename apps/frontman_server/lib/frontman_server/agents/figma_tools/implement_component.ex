defmodule FrontmanServer.Agents.FigmaTools.ImplementComponent do
  @moduledoc """
  Backend tool that spawns a sub-agent to implement a single UI component
  based on Figma design data.

  This tool is typically called after a breakdown_figma_node analysis, where
  each component from the breakdown can be implemented by spawning an
  implement_component sub-agent.

  The sub-agent has access to MCP tools (file operations, browser, etc.) to:
  1. Fetch the full Figma node data via get_figma_node
  2. Implement the component
  3. Verify the implementation visually
  """

  require Logger

  alias FrontmanServer.Agents.SubAgentExecutor
  alias FrontmanServer.Tasks

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

  @doc """
  Returns the tool definition for LLM.
  """
  @spec tool(String.t()) :: ReqLLM.Tool.t()
  def tool(task_id) do
    ReqLLM.Tool.new!(
      name: "implement_component",
      description: """
      Implement a single UI component based on Figma design data.

      Use this after breaking down a Figma design to implement each component.
      The tool will spawn a sub-agent that has access to browser tools for
      visual verification.
      """,
      parameter_schema: %{
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
      },
      callback: fn args -> execute(task_id, args) end
    )
  end

  @doc """
  Executes the implement component tool by spawning a sub-agent.
  """
  @spec execute(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def execute(task_id, args) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")

    # Get parent agent context from process dictionary (set by Tools.execute_tool)
    context = FrontmanServer.Tools.get_tool_context()
    parent_agent_id = Map.get(context, :agent_id)

    # Get MCP tools from task and convert to LLM format
    raw_mcp_tools = Tasks.get_mcp_tools(task_id)
    mcp_tools = mcp_tools_to_llm_format(raw_mcp_tools)

    Logger.info(
      "ImplementComponent: Starting implementation of #{component_name} (#{node_id}) with #{length(mcp_tools)} MCP tools"
    )

    # Build messages for sub-agent
    system_msg = ReqLLM.Context.system(@system_prompt, cache_control: %{type: "ephemeral"})
    user_msg = build_user_message(args)

    # Execute sub-agent with MCP tools
    case SubAgentExecutor.execute(task_id, [system_msg, user_msg],
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

  defp mcp_tools_to_llm_format(mcp_tools) do
    Enum.map(mcp_tools, fn tool ->
      ReqLLM.Tool.new!(
        name: tool["name"],
        description: tool["description"] || "",
        parameter_schema: tool["inputSchema"] || %{"type" => "object", "properties" => %{}},
        callback: fn _args -> {:ok, "MCP tool - executed externally"} end
      )
    end)
  end
end
