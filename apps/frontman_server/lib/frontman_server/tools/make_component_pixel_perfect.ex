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

  alias FrontmanServer.Agents.{SpecializedAgent, ToolExecutor}
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.MCP
  alias Swarm.Message

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
  def execute(args, %Context{task: task, agent_id: parent_agent_id, llm_opts: llm_opts}) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")

    mcp_tools = MCP.to_swarm_tools(task.mcp_tools)

    Logger.info(
      "MakeComponentPixelPerfect: Starting refinement of #{component_name} (#{node_id}) with #{length(mcp_tools)} MCP tools"
    )

    user_msg = build_user_message(args)

    # Extract markdown files for project conventions
    markdown_messages = extract_markdown_messages_from_task(task.task_id)
    messages = markdown_messages ++ [user_msg]

    # Build ComponentPixelPerfectAgent and executor
    agent_id = "pixel_perfectionist_#{parent_agent_id}"
    agent = SpecializedAgent.new(:component_pixel_perfect, tools: mcp_tools, llm_opts: llm_opts)
    tool_executor = ToolExecutor.make_executor(task.task_id, agent_id)

    case Swarm.run_blocking(agent, messages, tool_executor) do
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

    Message.user(task_text)
  end

  defp extract_markdown_messages_from_task(task_id) do
    task_id
    |> Tasks.get_interactions()
    |> Interaction.extract_markdown_messages()
  end
end
