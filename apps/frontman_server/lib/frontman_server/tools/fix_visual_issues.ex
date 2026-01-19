defmodule FrontmanServer.Tools.FixVisualIssues do
  @moduledoc """
  Spawns a sub-agent to fix visual discrepancies between a component and its Figma design.

  This tool takes the comparison result from visual_compare_component_to_figma and applies
  the fixes described in the howToFix instructions.

  The sub-agent:
  1. Reviews the comparison data
  2. Applies fixes following the howToFix instructions
  3. Takes ONE verification screenshot
  4. Reports what was fixed
  """

  @behaviour FrontmanServer.Tools.Backend

  require Logger

  alias FrontmanServer.Agents.SpecializedAgent
  alias FrontmanServer.Tools.Backend.Context
  alias Swarm.Message

  @impl true
  def name, do: "fix_visual_issues"

  @impl true
  def description do
    """
    Fix visual discrepancies between a component and its Figma design.

    Use this after visual_compare_component_to_figma identifies differences.
    Pass the comparison result fields and this tool will apply the fixes
    and verify with one screenshot.
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "componentName" => %{
          "type" => "string",
          "description" => "Name of the component being fixed"
        },
        "nodeId" => %{
          "type" => "string",
          "description" => "(Optional) The Figma node ID"
        },
        "figmaDesignDescription" => %{
          "type" => "string",
          "description" => "(Optional) Description of the Figma design from the comparison"
        },
        "implementationDescription" => %{
          "type" => "string",
          "description" =>
            "(Optional) Description of the current implementation from the comparison"
        },
        "keyDifferences" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Array of visual differences to fix"
        },
        "howToFix" => %{
          "type" => "string",
          "description" => "Instructions on how to fix the differences"
        },
        "componentFilePath" => %{
          "type" => "string",
          "description" => "The file path to the component"
        },
        "filesCreated" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "(Optional) List of file paths that may need modification"
        },
        "testPageUrl" => %{
          "type" => "string",
          "description" => "The URL path to the test page"
        },
        "dataTestId" => %{
          "type" => "string",
          "description" => "The data-test-id value used on the component's root element"
        }
      },
      "required" => [
        "componentName",
        "keyDifferences",
        "howToFix",
        "componentFilePath",
        "testPageUrl",
        "dataTestId"
      ]
    }
  end

  @impl true
  def execute(args, %Context{} = context) do
    %{
      tool_executor: tool_executor,
      mcp_tools: mcp_tools,
      context_messages: context_messages,
      llm_opts: llm_opts
    } = context

    component_name = Map.get(args, "componentName")

    Logger.info(
      "FixVisualIssues: Starting visual fixes for #{component_name} with #{length(mcp_tools)} MCP tools"
    )

    user_msg = build_user_message(args)
    messages = context_messages ++ [user_msg]

    agent = SpecializedAgent.new(:fix_visual_issues, tools: mcp_tools, llm_opts: llm_opts)

    case Swarm.run_blocking(agent, messages, tool_executor) do
      {:ok, result} ->
        Logger.info("FixVisualIssues: Completed for #{component_name}")

        {:ok,
         %{
           "fixResult" => result,
           "componentName" => component_name
         }}

      {:error, reason} ->
        Logger.error("FixVisualIssues: Failed - #{inspect(reason)}")
        {:error, "Visual fixes failed: #{inspect(reason)}"}
    end
  end

  defp build_user_message(args) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")
    figma_desc = Map.get(args, "figmaDesignDescription", "Not provided")
    impl_desc = Map.get(args, "implementationDescription", "Not provided")
    key_differences = Map.get(args, "keyDifferences", [])
    how_to_fix = Map.get(args, "howToFix", "")
    component_file_path = Map.get(args, "componentFilePath")
    files_created = Map.get(args, "filesCreated", [])
    test_page_url = Map.get(args, "testPageUrl")
    data_test_id = Map.get(args, "dataTestId")

    selector_str = if data_test_id, do: "[data-test-id=\"#{data_test_id}\"]", else: nil

    differences_str =
      key_differences
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {diff, i} -> "#{i}. #{diff}" end)

    files_str = Enum.map_join(files_created, "\n", &"  - #{&1}")

    task_text = """
    ## Fix Visual Issues

    - **Component:** #{component_name}
    - **Node ID:** #{node_id || "Not specified"}
    - **Component File:** #{component_file_path}
    - **Test Page URL:** #{test_page_url}
    - **CSS Selector:** `#{selector_str}`

    ## Figma Design Description

    #{figma_desc}

    ## Current Implementation Description

    #{impl_desc}

    ## Key Differences to Fix

    #{differences_str}

    ## How to Fix

    #{how_to_fix}

    ## Files Available

    #{files_str}

    ## Instructions

    1. Apply the fixes described in "How to Fix" above
    2. Navigate to `#{test_page_url}`
    3. Take ONE screenshot to verify improvements
    4. Use `navigate_back` to leave the test page
    5. Return a JSON result with:
       - `changesApplied`: Array of changes made
       - `remainingIssues`: Array of issues that couldn't be fixed
       - `filesModified`: Array of files that were modified
       - `verificationResult`: Brief description of the verification
    """

    Message.user(task_text)
  end
end
