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
  You are a visual refinement specialist. Your task is to fix visual issues
  in a component implementation to make it match the Figma design.

  ## Project Context & Conventions

  **CRITICAL:** If you have been provided with project documentation, research findings,
  or convention files, you MUST follow them. Use modern CSS (Flexbox, Grid) and the
  project's styling approach (Tailwind, CSS modules, etc.).

  ## Your Goal

  You are provided with:
  - A description of what the Figma design looks like
  - A description of what the current implementation looks like
  - Key differences between them
  - Instructions on how to fix those differences

  Your job is to implement those fixes to make the component match the design.

  ## Instructions

  1. **Understand the context** - Study the descriptions of both images and the differences

  2. **Follow the fix instructions** - The "How to Fix" section provides specific guidance
     on what CSS/code changes to make. Follow these instructions carefully.

  3. **Make targeted fixes** - Update the component files:
     - Apply the exact fixes described
     - Use proper CSS properties and values
     - Follow project styling conventions

  4. **Verify your improvements (ONCE)** - After making all fixes:
     a. Use `get_figma_node` to fetch the Figma design image for reference
     b. Navigate to the test page
     c. Take a screenshot using the provided selector
     d. Compare to verify improvements
     - **You may only do this verification step ONCE** - make all your fixes before checking

  5. **Navigate back** - Use `navigate_back` tool to leave the test page

  6. **Report result** - Provide a structured JSON result

  ## Output Format

  **CRITICAL:** Your response MUST end with a JSON code block containing the result.

  ```json
  {
    "changesApplied": [
      "Added gradient background: linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
      "Updated title color to white (#FFFFFF)",
      "Increased padding from 16px to 24px"
    ],
    "remainingIssues": [],
    "filesModified": ["path/to/Component.tsx"],
    "verificationResult": "Component now matches the Figma design closely",
    "summary": "Applied all recommended fixes. The gradient background, typography, and spacing now match the design."
  }
  ```

  **JSON Field Requirements:**
  - `changesApplied`: Array of specific changes you made
  - `remainingIssues`: Array of issues that could not be fixed or need more work
  - `filesModified`: Array of file paths that were modified
  - `verificationResult`: What you observed when comparing after your fixes
  - `summary`: Brief summary of what was done and the result

  ## Guidelines

  - Make precise, targeted changes - don't refactor unrelated code
  - Use the exact values from the fix instructions when provided
  - Follow project styling conventions
  - Avoid hacks or workarounds - use proper CSS
  - You have ONE verification step - use it wisely after making all fixes

  IMPORTANT INSTRUCTIONS:
  - Do NOT engage in conversation or ask clarifying questions
  - Focus ONLY on implementing the fixes described
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
        "figmaDesignDescription" => %{
          "type" => "string",
          "description" =>
            "Detailed description of the Figma design image from visual comparison"
        },
        "implementationDescription" => %{
          "type" => "string",
          "description" =>
            "Detailed description of the current implementation from visual comparison"
        },
        "keyDifferences" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Key visual differences identified between design and implementation"
        },
        "howToFix" => %{
          "type" => "string",
          "description" =>
            "Comprehensive instructions on how to fix all visual issues"
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
        "keyDifferences",
        "howToFix",
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
    figma_description = Map.get(args, "figmaDesignDescription", "")
    implementation_description = Map.get(args, "implementationDescription", "")
    key_differences = Map.get(args, "keyDifferences", [])
    how_to_fix = Map.get(args, "howToFix", "")
    component_file_path = Map.get(args, "componentFilePath")
    files_created = Map.get(args, "filesCreated", [])
    test_page_url = Map.get(args, "testPageUrl")
    test_page_file_path = Map.get(args, "testPageFilePath")
    data_test_id = Map.get(args, "dataTestId")

    selector_str = if data_test_id, do: "[data-test-id=\"#{data_test_id}\"]", else: nil

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

    figma_description_str =
      if figma_description != "" do
        """

        ## What the Figma Design Looks Like

        #{figma_description}
        """
      else
        ""
      end

    implementation_description_str =
      if implementation_description != "" do
        """

        ## What the Current Implementation Looks Like

        #{implementation_description}
        """
      else
        ""
      end

    key_differences_str =
      if key_differences != [] do
        differences_list =
          key_differences
          |> Enum.with_index(1)
          |> Enum.map(fn {diff, idx} -> "#{idx}. #{diff}" end)
          |> Enum.join("\n")

        """

        ## Key Differences to Fix

        #{differences_list}
        """
      else
        ""
      end

    how_to_fix_str =
      if how_to_fix != "" do
        """

        ## How to Fix These Issues

        #{how_to_fix}
        """
      else
        ""
      end

    task_text = """
    ## Fix Visual Issues

    - **Component:** #{component_name}
    - **Node ID:** #{node_id}
    - **Component File:** #{component_file_path}
    - **Test Page URL:** #{test_page_url}#{test_page_path_str}
    - **Data Test ID:** `#{data_test_id}`#{selector_instruction}
    #{files_str}#{figma_description_str}#{implementation_description_str}#{key_differences_str}#{how_to_fix_str}
    ## Instructions

    1. Read the component file(s) and understand the current implementation
    2. Follow the "How to Fix" instructions above to make all necessary changes
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
          "changesApplied" => Map.get(json_data, "changesApplied", []),
          "remainingIssues" => Map.get(json_data, "remainingIssues", []),
          "filesModified" => Map.get(json_data, "filesModified", []),
          "verificationResult" => Map.get(json_data, "verificationResult", ""),
          "summary" => Map.get(json_data, "summary", ""),
          "rawResponse" => result
        }

      :error ->
        Logger.warning("FixVisualIssues: Could not parse JSON from response")

        %{
          "componentName" => component_name,
          "nodeId" => node_id,
          "changesApplied" => [],
          "remainingIssues" => ["Could not parse fix result"],
          "filesModified" => [],
          "verificationResult" => "",
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
        case Regex.run(~r/\{[\s\S]*"changesApplied"[\s\S]*\}/, response) do
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
