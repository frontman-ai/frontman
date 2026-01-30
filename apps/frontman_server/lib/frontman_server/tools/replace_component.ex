defmodule FrontmanServer.Tools.ReplaceComponent do
  @moduledoc """
  Spawns a sub-agent to replace an existing component with a new implementation.

  This tool handles the replacement of an old component with the newly implemented version,
  including updating imports and cleaning up temporary files.

  The sub-agent:
  1. Reads both source and target files
  2. Replaces the target with the source content
  3. Updates imports if needed
  4. Cleans up temporary files (source, test page)
  """

  @behaviour FrontmanServer.Tools.Backend

  require Logger

  alias FrontmanServer.Agents.SpecializedAgent
  alias FrontmanServer.Tools.Backend.Context
  alias Swarm.Message

  @impl true
  def name, do: "replace_component"

  @impl true
  def description do
    """
    Replace an existing component with a new implementation.

    Use this after the component has been implemented and verified.
    The tool replaces the old component file with the new one,
    updates imports if needed, and cleans up temporary files.
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
          "description" => "The file path to the new implementation (from implement_component)"
        },
        "targetFilePath" => %{
          "type" => "string",
          "description" => "The file path to the old component to replace"
        },
        "testPageFilePath" => %{
          "type" => "string",
          "description" => "(Optional) The file path to the test page to delete"
        },
        "filesCreated" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "(Optional) List of all files created during implementation"
        }
      },
      "required" => ["componentName", "sourceFilePath", "targetFilePath"]
    }
  end

  @impl true
  def execute(args, %Context{
        mcp_tools: mcp_tools,
        tool_executor: tool_executor,
        llm_opts: llm_opts
      }) do
    component_name = Map.get(args, "componentName")
    source_file_path = Map.get(args, "sourceFilePath")
    target_file_path = Map.get(args, "targetFilePath")

    Logger.info("ReplaceComponent: Replacing #{target_file_path} with #{source_file_path}")

    user_msg = build_user_message(args)

    agent =
      SpecializedAgent.new(:replace_component,
        tools: mcp_tools,
        model: llm_opts[:model],
        llm_opts: llm_opts
      )

    case Swarm.run_blocking(agent, [user_msg], tool_executor) do
      {:ok, result, _loop_id} ->
        Logger.info("ReplaceComponent: Completed for #{component_name}")

        {:ok,
         %{
           "replacementResult" => result,
           "componentName" => component_name,
           "sourceFilePath" => source_file_path,
           "targetFilePath" => target_file_path
         }}

      {:error, reason, _loop_id} ->
        Logger.error("ReplaceComponent: Failed - #{inspect(reason)}")
        {:error, "Replacement failed: #{inspect(reason)}"}
    end
  end

  defp build_user_message(args) do
    component_name = Map.get(args, "componentName")
    source_file_path = Map.get(args, "sourceFilePath")
    target_file_path = Map.get(args, "targetFilePath")
    test_page_file_path = Map.get(args, "testPageFilePath")
    files_created = Map.get(args, "filesCreated", [])

    files_str = Enum.map_join(files_created, "\n", &"  - #{&1}")

    cleanup_instructions =
      if test_page_file_path do
        "4. Delete the test page file at `#{test_page_file_path}`"
      else
        "4. Clean up any temporary files"
      end

    task_text = """
    ## Replace Component

    - **Component:** #{component_name}
    - **Source (new implementation):** #{source_file_path}
    - **Target (old component):** #{target_file_path}
    - **Test Page to Delete:** #{test_page_file_path || "None specified"}

    ## Files Created During Implementation

    #{files_str}

    ## Instructions

    1. Read the source file at `#{source_file_path}`
    2. Read the target file at `#{target_file_path}` to understand the current component
    3. Replace the content of the target file with the source content:
       - Update the component name if it differs
       - Preserve the original exports
       - Adjust any component-specific naming
    #{cleanup_instructions}
    5. Delete the source file (it was temporary)
    6. Search for and update any imports if the component structure changed

    ## Return Format

    Return a JSON result with:
    - `replacementComplete`: Boolean indicating success
    - `targetFilePath`: The final path of the replaced component
    - `filesModified`: Array of files that were modified
    - `filesDeleted`: Array of files that were deleted
    - `importsUpdated`: Array of files where imports were updated
    - `summary`: Brief description of what was done
    """

    Message.user(task_text)
  end
end
