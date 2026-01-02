defmodule FrontmanServer.Tools.FixFilesErrors do
  @moduledoc """
  Spawns a sub-agent to fix errors in the created component files.

  This tool is called after implement_component completes. It takes the list of created files,
  navigates to the test page, checks for runtime errors, and fixes any issues found.

  The sub-agent:
  1. Navigates to the test page
  2. Uses get_errors to check for runtime/compilation errors
  3. Fixes any errors found in the component files
  4. Repeats until no errors remain or max iterations reached
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
  You are a frontend error resolution specialist. Your task is to fix any errors
  in the recently implemented component files.

  ## Project Context & Conventions

  **CRITICAL:** If you have been provided with project documentation, research findings,
  or convention files, you MUST follow them throughout the error fixing process.

  ## Your Goal

  Fix all errors in the component implementation so it renders without errors.
  Focus on:
  - TypeScript/JavaScript compilation errors
  - React rendering errors
  - Import/export issues
  - Runtime exceptions
  - Missing dependencies

  ## Instructions

  1. **Navigate to test page** - Use `navigate` tool with the test page URL provided in your task

  2. **Check for errors** - Use `get_errors` tool to check for errors

  3. **Error fixing loop** (max 5 iterations):
     a. **Analyze errors** - Review any errors returned by get_errors
     b. **Fix errors** - Make targeted fixes to the component files
     c. **Re-check** - Navigate and check for errors again
     d. **Repeat** until no errors or max iterations reached

  4. **Navigate back** - Use `navigate_back` tool to leave the test page

  5. **Return result** - Report whether all errors were fixed

  ## Output Format

  **CRITICAL:** Your response MUST end with a JSON code block containing the result.

  ```json
  {
    "errorsFixed": true,
    "remainingErrors": [],
    "filesModified": ["path/to/file.tsx"],
    "summary": "Fixed import error in Component.tsx"
  }
  ```

  **JSON Field Requirements:**
  - `errorsFixed`: Boolean indicating if all errors were resolved
  - `remainingErrors`: Array of any errors that could not be fixed
  - `filesModified`: Array of file paths that were modified
  - `summary`: Brief summary of what was fixed

  IMPORTANT INSTRUCTIONS:
  - Focus ONLY on fixing errors, not on visual improvements
  - Make minimal, targeted fixes
  - Do NOT refactor or change component functionality
  - Do NOT engage in conversation or ask clarifying questions
  - **DO NOT use `take_screenshot`** - visual comparison is done by a separate tool
  - **DO NOT use `get_figma_node`** - you only need to fix code errors
  - **ALWAYS use `navigate_back` before returning** to leave the test page
  - Complete your task and return the JSON result
  """

  @impl true
  def name, do: "fix_files_errors"

  @impl true
  def description do
    """
    Fix errors in component files after implementation.

    Use this after implement_component to check for and fix any runtime or compilation errors.
    The tool navigates to the test page, checks for errors, and fixes them.

    Returns a structured result indicating if all errors were fixed.
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
        "filesCreated" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "List of file paths created by implement_component"
        },
        "testPageUrl" => %{
          "type" => "string",
          "description" => "The URL path to navigate to the test page (e.g., '/test-component-name')"
        },
        "testPageFilePath" => %{
          "type" => "string",
          "description" => "The file path to the test page"
        }
      },
      "required" => ["componentName", "filesCreated", "testPageUrl"]
    }
  end

  @impl true
  def execute(args, %Context{task: task, agent_id: parent_agent_id, llm_opts: llm_opts}) do
    component_name = Map.get(args, "componentName")
    files_created = Map.get(args, "filesCreated", [])

    mcp_tools = MCP.to_llm_format(task.mcp_tools)

    Logger.info(
      "FixFilesErrors: Starting error fixing for #{component_name} with #{length(files_created)} files"
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
           role: "error_fixer",
           parent_agent_id: parent_agent_id,
           spawning_tool_name: name(),
           llm_opts: llm_opts
         ) do
      {:ok, result} ->
        Logger.info("FixFilesErrors: Completed for #{component_name}")

        parsed_result = parse_fix_result(result, component_name)
        {:ok, parsed_result}

      {:error, reason} ->
        Logger.error("FixFilesErrors: Failed - #{inspect(reason)}")
        {:error, "Error fixing failed: #{inspect(reason)}"}
    end
  end

  defp build_user_message(args) do
    component_name = Map.get(args, "componentName")
    files_created = Map.get(args, "filesCreated", [])
    test_page_url = Map.get(args, "testPageUrl")
    test_page_file_path = Map.get(args, "testPageFilePath")

    files_str =
      files_created
      |> Enum.map(&"  - #{&1}")
      |> Enum.join("\n")

    test_page_path_str =
      if test_page_file_path, do: "\n- **Test Page File Path:** #{test_page_file_path}", else: ""

    task_text = """
    ## Fix Component Errors

    - **Component:** #{component_name}
    - **Test Page URL:** #{test_page_url}#{test_page_path_str}

    ## Files to Check

    #{files_str}

    ## First Step

    Navigate to the test page at `#{test_page_url}` and use `get_errors` to check for any errors.
    Fix any errors found, then check again until no errors remain.
    """

    ReqLLM.Context.user(task_text)
  end

  # Parses the JSON block from the agent's response
  defp parse_fix_result(result, component_name) do
    case extract_json_from_response(result) do
      {:ok, json_data} ->
        %{
          "componentName" => component_name,
          "errorsFixed" => Map.get(json_data, "errorsFixed", false),
          "remainingErrors" => Map.get(json_data, "remainingErrors", []),
          "filesModified" => Map.get(json_data, "filesModified", []),
          "summary" => Map.get(json_data, "summary", ""),
          "rawResponse" => result
        }

      :error ->
        Logger.warning("FixFilesErrors: Could not parse JSON from response")

        %{
          "componentName" => component_name,
          "errorsFixed" => false,
          "remainingErrors" => ["Could not parse result"],
          "filesModified" => [],
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
        case Regex.run(~r/\{[\s\S]*"errorsFixed"[\s\S]*\}/, response) do
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
