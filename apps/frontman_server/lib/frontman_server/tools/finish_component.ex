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

  alias FrontmanServer.Agents.{ComponentFinishAgent, ToolExecutor}
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.MCP
  alias Swarm.Message

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
  def execute(args, %Context{task: task, agent_id: parent_agent_id, llm_opts: llm_opts}) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")

    mcp_tools = MCP.to_swarm_tools(task.mcp_tools)

    Logger.info(
      "FinishComponent: Starting verification of #{component_name} (#{node_id}) with #{length(mcp_tools)} MCP tools"
    )

    user_msg = build_user_message(args)

    # Extract markdown files for project conventions
    markdown_messages = extract_markdown_messages_from_task(task.task_id)
    messages = markdown_messages ++ [user_msg]

    # Build ComponentFinishAgent and executor
    agent_id = "component_finisher_#{parent_agent_id}"
    agent = ComponentFinishAgent.new(tools: mcp_tools, llm_opts: llm_opts)
    tool_executor = ToolExecutor.make_executor(task.task_id, agent_id)

    case Swarm.run_blocking(agent, messages, tool_executor) do
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

    Message.user(task_text)
  end

  defp extract_markdown_messages_from_task(task_id) do
    task_id
    |> Tasks.get_interactions()
    |> Interaction.extract_markdown_messages()
  end
end
