defmodule FrontmanServer.Tools.VisualCompareComponentToFigma do
  @moduledoc """
  Spawns a sub-agent to compare a component implementation against its Figma design.

  This tool takes screenshots of the implementation and compares them to the Figma design,
  producing a structured comparison result with descriptions, differences, and fix instructions.

  The sub-agent:
  1. Fetches the Figma node image
  2. Navigates to the test page
  3. Takes a screenshot of the component
  4. Compares the two images and produces a detailed analysis
  """

  @behaviour FrontmanServer.Tools.Backend

  require Logger

  alias FrontmanServer.Agents.SpecializedAgent
  alias FrontmanServer.Tools.Backend.Context
  alias Swarm.Message

  @impl true
  def name, do: "visual_compare_component_to_figma"

  @impl true
  def description do
    """
    Compare a component implementation against its Figma design.

    Takes screenshots of the implementation and compares them to the Figma design image.
    Returns a structured comparison result with:
    - Detailed descriptions of both images
    - List of visual differences
    - Instructions on how to fix the differences
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
          "description" => "The URL path to the test page"
        },
        "componentFilePath" => %{
          "type" => "string",
          "description" => "(Optional) The file path to the component"
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
  def execute(args, %Context{
        tool_executor: tool_executor,
        mcp_tools: mcp_tools,
        llm_opts: llm_opts
      }) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")

    Logger.info(
      "VisualCompare: Starting comparison for #{component_name} (#{node_id}) with #{length(mcp_tools)} MCP tools"
    )

    user_msg = build_user_message(args)

    agent =
      SpecializedAgent.new(:visual_compare,
        tools: mcp_tools,
        model: llm_opts[:model],
        llm_opts: llm_opts
      )

    case Swarm.run_blocking(agent, [user_msg], tool_executor) do
      {:ok, result} ->
        Logger.info("VisualCompare: Completed comparison for #{component_name}")

        {:ok,
         %{
           "comparisonResult" => result,
           "componentName" => component_name,
           "nodeId" => node_id
         }}

      {:error, reason} ->
        Logger.error("VisualCompare: Failed - #{inspect(reason)}")
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

    task_text = """
    ## Visual Comparison Task

    - **Component:** #{component_name}
    - **Node ID:** #{node_id}
    - **Test Page URL:** #{test_page_url}
    - **Component File:** #{component_file_path || "Not specified"}
    - **Data Test ID:** `#{data_test_id}`
    - **CSS Selector:** `#{selector_str}`

    ## Instructions

    1. Use `get_figma_node` with:
       - nodeId: "#{node_id}"
       - includeImage: true
       - withChildren: false

    2. Navigate to `#{test_page_url}`

    3. Take a screenshot using `take_screenshot` with selector: `#{selector_str}`

    4. Compare the Figma design image with the implementation screenshot

    5. Use `navigate_back` to leave the test page

    6. Return a JSON result with:
       - `figmaDesignDescription`: Detailed description of the Figma design
       - `implementationDescription`: Detailed description of the implementation
       - `keyDifferences`: Array of specific visual differences
       - `howToFix`: Step-by-step instructions to fix ALL differences
       - `overallMatch`: "good" | "partial" | "poor"
    """

    Message.user(task_text)
  end
end
