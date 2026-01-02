defmodule FrontmanServer.Tools.ReplaceComponent do
  @moduledoc """
  Spawns a sub-agent to replace an existing component with a new implementation.

  This tool is called after the component has been implemented and visually verified.
  It takes the new component file path and the target location (where to replace),
  and performs the replacement including import updates.

  The sub-agent:
  1. Reads the new component implementation
  2. Reads the old component to understand its exports and usage
  3. Replaces the old component with the new implementation
  4. Updates imports in files that use the component
  5. Reports what files were modified

  After this tool completes, use `fix_files_errors` on the replaced component location.
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
  You are a code integration specialist. Your task is to replace an existing component
  with a new implementation, ensuring all imports and usages are updated correctly.

  ## Project Context & Conventions

  **CRITICAL:** If you have been provided with project documentation, research findings,
  or convention files, you MUST follow them throughout the replacement process.

  ## Your Goal

  Replace the old component at the target location with the new implementation,
  ensuring the codebase continues to work correctly.

  ## Instructions

  1. **Read the new component** - Read the new component file to understand:
     - Its exports (default export, named exports)
     - Its props/interface
     - Any dependencies it has

  2. **Read the old component** - Read the component at the target location to understand:
     - Its current exports
     - Its current props/interface
     - How it differs from the new implementation

  3. **Replace the component** - Copy the new implementation to the target location:
     - If the file paths are different, you may need to adjust imports within the component
     - Ensure the export style matches what consumers expect (or update consumers)
     - Preserve any important comments or documentation from the old component if relevant

  4. **Update imports** - Search for files that import the component:
     - Use `grep` to find imports of the component
     - Update any import paths if they changed
     - Update any named imports if export names changed

  5. **Report result** - Provide a structured JSON result

  ## Output Format

  **CRITICAL:** Your response MUST end with a JSON code block containing the result.

  ```json
  {
    "replacementSuccessful": true,
    "targetFilePath": "path/to/replaced/Component.tsx",
    "filesModified": [
      "path/to/replaced/Component.tsx",
      "path/to/consumer/Page.tsx"
    ],
    "importsUpdated": 2,
    "summary": "Replaced Header component. Updated 2 files that import it."
  }
  ```

  **JSON Field Requirements:**
  - `replacementSuccessful`: Boolean indicating if the replacement was successful
  - `targetFilePath`: The file path where the component was replaced
  - `filesModified`: Array of all file paths that were modified
  - `importsUpdated`: Number of files where imports were updated
  - `summary`: Brief summary of what was done

  ## Guidelines

  - Preserve the component's public interface if possible
  - If exports change, update all consumers
  - Be careful not to break the build

  IMPORTANT INSTRUCTIONS:
  - Do NOT engage in conversation or ask clarifying questions
  - Focus on making a clean replacement without breaking the codebase
  - Complete your task and return the JSON result
  """

  @impl true
  def name, do: "replace_component"

  @impl true
  def description do
    """
    Replace an existing component with a new implementation.

    Use this after visual verification to replace the old component at the target location
    with the new implementation. The tool handles updating imports across the codebase.

    After this tool completes, use `fix_files_errors` on the target file to ensure
    the component works correctly in its final location.
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "componentName" => %{
          "type" => "string",
          "description" => "Name of the component being replaced"
        },
        "sourceFilePath" => %{
          "type" => "string",
          "description" => "Path to the new component implementation (from implement_component)"
        },
        "targetFilePath" => %{
          "type" => "string",
          "description" => "Path where the component should be replaced (the selected component location)"
        }
      },
      "required" => ["componentName", "sourceFilePath", "targetFilePath"]
    }
  end

  @impl true
  def execute(args, %Context{task: task, agent_id: parent_agent_id, llm_opts: llm_opts}) do
    component_name = Map.get(args, "componentName")
    target_file_path = Map.get(args, "targetFilePath")

    mcp_tools = MCP.to_llm_format(task.mcp_tools)

    Logger.info(
      "ReplaceComponent: Replacing #{component_name} at #{target_file_path}"
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
           role: "component_replacer",
           parent_agent_id: parent_agent_id,
           spawning_tool_name: name(),
           llm_opts: llm_opts
         ) do
      {:ok, result} ->
        Logger.info("ReplaceComponent: Completed replacement of #{component_name}")

        parsed_result = parse_replacement_result(result, component_name, target_file_path)
        {:ok, parsed_result}

      {:error, reason} ->
        Logger.error("ReplaceComponent: Failed - #{inspect(reason)}")
        {:error, "Replacement failed: #{inspect(reason)}"}
    end
  end

  defp build_user_message(args) do
    component_name = Map.get(args, "componentName")
    source_file_path = Map.get(args, "sourceFilePath")
    target_file_path = Map.get(args, "targetFilePath")

    task_text = """
    ## Replace Component

    - **Component:** #{component_name}
    - **Source File (new implementation):** #{source_file_path}
    - **Target File (where to replace):** #{target_file_path}

    ## Instructions

    1. Read both the source file (new implementation) and target file (old component)
    2. Replace the target file with the new implementation
    3. Search for imports of the component and update them if needed
    4. If the source file is different from the target, delete the source file after copying
    5. Report all files that were modified
    """

    ReqLLM.Context.user(task_text)
  end

  # Parses the JSON block from the agent's response
  defp parse_replacement_result(result, component_name, target_file_path) do
    case extract_json_from_response(result) do
      {:ok, json_data} ->
        %{
          "componentName" => component_name,
          "replacementSuccessful" => Map.get(json_data, "replacementSuccessful", false),
          "targetFilePath" => Map.get(json_data, "targetFilePath", target_file_path),
          "filesModified" => Map.get(json_data, "filesModified", []),
          "importsUpdated" => Map.get(json_data, "importsUpdated", 0),
          "summary" => Map.get(json_data, "summary", ""),
          "rawResponse" => result
        }

      :error ->
        Logger.warning("ReplaceComponent: Could not parse JSON from response")

        %{
          "componentName" => component_name,
          "replacementSuccessful" => false,
          "targetFilePath" => target_file_path,
          "filesModified" => [],
          "importsUpdated" => 0,
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
        case Regex.run(~r/\{[\s\S]*"replacementSuccessful"[\s\S]*\}/, response) do
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
