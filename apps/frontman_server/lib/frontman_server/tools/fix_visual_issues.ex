defmodule FrontmanServer.Tools.FixVisualIssues do
  @moduledoc """
  Spawns a sub-agent to fix visual issues identified by visual_compare_component_to_figma.

  This tool is called after visual comparison completes. It takes the Figma node ID,
  component description, visual errors, implementation files, and test page, then
  makes targeted fixes to resolve the visual discrepancies.

  The sub-agent:
  1. Reviews the visual issues to fix
  2. Makes code changes to address the issues
  3. Verifies improvements with ONE screenshot comparison against Figma
  4. Reports the result

  After this tool completes, the main agent can proceed to replace the component.
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
  You are a visual refinement specialist. Your task is to fix specific visual issues
  in a component implementation to better match the Figma design.

  ## Project Context & Conventions

  **CRITICAL:** If you have been provided with project documentation, research findings,
  or convention files, you MUST follow them. Use modern CSS (Flexbox, Grid) and the
  project's styling approach (Tailwind, CSS modules, etc.).

  ## Your Goal

  Fix the specific visual issues identified in the comparison to make the component
  more closely match the Figma design. Focus on the issues provided - do not over-engineer
  or make unnecessary changes.

  ## Instructions

  1. **Review the issues** - Study the visual issues provided in your task:
     - Critical issues should be fixed first
     - Minor issues should also be addressed
     - Each issue describes what is wrong and often includes specific values

  2. **Make targeted fixes** - Update the component files to address each issue:
     - Fix spacing values (padding, margin, gap)
     - Correct colors and typography
     - Adjust layout alignment
     - Use project-appropriate CSS patterns

  3. **Verify your improvements (ONCE)** - After making all fixes:
     a. Use `get_figma_node` to fetch the Figma design image for reference
     b. Navigate to the test page
     c. Take a screenshot using the provided selector
     d. Compare to verify improvements
     - **You may only do this verification step ONCE** - make all your fixes before checking

  4. **Navigate back** - Use `navigate_back` tool to leave the test page

  5. **Report result** - Provide a structured JSON result

  ## Output Format

  **CRITICAL:** Your response MUST end with a JSON code block containing the result.

  ```json
  {
    "issuesFixed": [
      "Fixed padding from 16px to 24px",
      "Updated font weight from 400 to 600"
    ],
    "issuesRemaining": [],
    "filesModified": ["path/to/Component.tsx"],
    "improvementAssessment": "good",
    "summary": "Fixed all critical and minor issues. Component now closely matches the design."
  }
  ```

  **JSON Field Requirements:**
  - `issuesFixed`: Array of issues that were successfully fixed
  - `issuesRemaining`: Array of issues that could not be fixed or need more work
  - `filesModified`: Array of file paths that were modified
  - `improvementAssessment`: One of "excellent", "good", "partial", "minimal"
  - `summary`: Brief summary of what was done and the result

  ## Guidelines

  - Make precise, targeted changes - don't refactor unrelated code
  - Use the exact values mentioned in the issues when available
  - Follow project styling conventions
  - Avoid hacks or workarounds - use proper CSS
  - You have ONE verification step - use it wisely after making all fixes

  IMPORTANT INSTRUCTIONS:
  - Do NOT engage in conversation or ask clarifying questions
  - Focus ONLY on fixing the specific visual issues provided
  - **ALWAYS use `navigate_back` before returning** to leave the test page
  - Complete your task and return the JSON result
  """

  @impl true
  def name, do: "fix_visual_issues"

  @impl true
  def description do
    """
    Fix visual issues identified by visual_compare_component_to_figma.

    Use this after visual comparison to fix specific visual discrepancies between
    the implementation and Figma design. The tool makes targeted fixes and verifies
    improvements with one screenshot comparison.

    After this tool completes, the main agent can proceed to replace the component.
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
          "description" => "The Figma node ID for reference (WITHOUT the # prefix)"
        },
        "description" => %{
          "type" => "string",
          "description" => "Description of the component and what it should look like"
        },
        "criticalIssues" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Critical visual issues that must be fixed"
        },
        "minorIssues" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Minor visual issues that should be fixed"
        },
        "componentFilePath" => %{
          "type" => "string",
          "description" => "Path to the main component file"
        },
        "filesCreated" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "List of all file paths created during implementation"
        },
        "testPageUrl" => %{
          "type" => "string",
          "description" => "The URL path to navigate to the test page"
        },
        "testPageFilePath" => %{
          "type" => "string",
          "description" => "The file path to the test page"
        },
        "dataTestId" => %{
          "type" => "string",
          "description" => "The data-test-id value used on the component's root element"
        }
      },
      "required" => [
        "componentName",
        "nodeId",
        "criticalIssues",
        "componentFilePath",
        "testPageUrl",
        "dataTestId"
      ]
    }
  end

  @impl true
  def execute(args, %Context{task: task, agent_id: parent_agent_id, llm_opts: llm_opts}) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")

    mcp_tools = MCP.to_llm_format(task.mcp_tools)

    Logger.info(
      "FixVisualIssues: Starting fixes for #{component_name} (#{node_id})"
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
           role: "visual_fixer",
           parent_agent_id: parent_agent_id,
           spawning_tool_name: name(),
           llm_opts: llm_opts
         ) do
      {:ok, result} ->
        Logger.info("FixVisualIssues: Completed fixes for #{component_name}")

        parsed_result = parse_fix_result(result, component_name, node_id)
        {:ok, parsed_result}

      {:error, reason} ->
        Logger.error("FixVisualIssues: Failed - #{inspect(reason)}")
        {:error, "Visual fix failed: #{inspect(reason)}"}
    end
  end

  defp build_user_message(args) do
    component_name = Map.get(args, "componentName")
    node_id = Map.get(args, "nodeId")
    description = Map.get(args, "description", "")
    critical_issues = Map.get(args, "criticalIssues", [])
    minor_issues = Map.get(args, "minorIssues", [])
    component_file_path = Map.get(args, "componentFilePath")
    files_created = Map.get(args, "filesCreated", [])
    test_page_url = Map.get(args, "testPageUrl")
    test_page_file_path = Map.get(args, "testPageFilePath")
    data_test_id = Map.get(args, "dataTestId")

    selector_str = if data_test_id, do: "[data-test-id=\"#{data_test_id}\"]", else: nil

    description_str =
      if description != "" do
        "\n- **Description:** #{description}"
      else
        ""
      end

    test_page_path_str =
      if test_page_file_path,
        do: "\n- **Test Page File Path:** #{test_page_file_path}",
        else: ""

    selector_instruction =
      if selector_str do
        "\n- **Selector:** `#{selector_str}` (Use this with `take_screenshot` to capture ONLY the component)"
      else
        ""
      end

    files_str =
      if files_created != [] do
        files_list =
          files_created
          |> Enum.map(&"  - #{&1}")
          |> Enum.join("\n")

        """

        ## All Files

        #{files_list}
        """
      else
        ""
      end

    critical_issues_str =
      if critical_issues != [] do
        issues_list =
          critical_issues
          |> Enum.with_index(1)
          |> Enum.map(fn {issue, idx} -> "#{idx}. #{issue}" end)
          |> Enum.join("\n")

        """

        ## Critical Issues to Fix

        #{issues_list}
        """
      else
        "\n## Critical Issues to Fix\n\nNone - focus on minor issues."
      end

    minor_issues_str =
      if minor_issues != [] do
        issues_list =
          minor_issues
          |> Enum.with_index(1)
          |> Enum.map(fn {issue, idx} -> "#{idx}. #{issue}" end)
          |> Enum.join("\n")

        """

        ## Minor Issues to Fix

        #{issues_list}
        """
      else
        ""
      end

    task_text = """
    ## Fix Visual Issues

    - **Component:** #{component_name}
    - **Node ID:** #{node_id}#{description_str}
    - **Component File:** #{component_file_path}
    - **Test Page URL:** #{test_page_url}#{test_page_path_str}
    - **Data Test ID:** `#{data_test_id}`#{selector_instruction}
    #{files_str}#{critical_issues_str}#{minor_issues_str}
    ## Instructions

    1. Read the component file(s) and understand the current implementation
    2. Make targeted fixes to address each issue listed above
    3. After ALL fixes are made, verify ONCE:
       - Use `get_figma_node` with nodeId: "#{node_id}", includeImage: true
       - Navigate to `#{test_page_url}`
       - Take a screenshot using the selector
       - Assess if improvements were successful

    Remember: You only get ONE verification step, so make all your fixes first!
    """

    ReqLLM.Context.user(task_text)
  end

  # Parses the JSON block from the agent's response
  defp parse_fix_result(result, component_name, node_id) do
    case extract_json_from_response(result) do
      {:ok, json_data} ->
        %{
          "componentName" => component_name,
          "nodeId" => node_id,
          "issuesFixed" => Map.get(json_data, "issuesFixed", []),
          "issuesRemaining" => Map.get(json_data, "issuesRemaining", []),
          "filesModified" => Map.get(json_data, "filesModified", []),
          "improvementAssessment" => Map.get(json_data, "improvementAssessment", "unknown"),
          "summary" => Map.get(json_data, "summary", ""),
          "rawResponse" => result
        }

      :error ->
        Logger.warning("FixVisualIssues: Could not parse JSON from response")

        %{
          "componentName" => component_name,
          "nodeId" => node_id,
          "issuesFixed" => [],
          "issuesRemaining" => ["Could not parse fix result"],
          "filesModified" => [],
          "improvementAssessment" => "unknown",
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
        case Regex.run(~r/\{[\s\S]*"issuesFixed"[\s\S]*\}/, response) do
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
