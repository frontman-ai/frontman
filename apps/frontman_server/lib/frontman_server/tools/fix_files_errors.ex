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

  alias FrontmanServer.Agents.SpecializedAgent
  alias FrontmanServer.Tools.Backend.Context
  alias Swarm.Message

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
          "description" =>
            "The URL path to navigate to the test page (e.g., '/test-component-name')"
        }
      },
      "required" => ["componentName", "filesCreated", "testPageUrl"]
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
    files_created = Map.get(args, "filesCreated", [])
    test_page_url = Map.get(args, "testPageUrl")

    Logger.info(
      "FixFilesErrors: Starting error fixing for #{component_name} with #{length(mcp_tools)} MCP tools"
    )

    user_msg = build_user_message(args)
    messages = context_messages ++ [user_msg]

    agent = SpecializedAgent.new(:fix_files_errors, tools: mcp_tools, llm_opts: llm_opts)

    case Swarm.run_blocking(agent, messages, tool_executor) do
      {:ok, result} ->
        Logger.info("FixFilesErrors: Completed for #{component_name}")

        {:ok,
         %{
           "result" => result,
           "componentName" => component_name,
           "filesCreated" => files_created,
           "testPageUrl" => test_page_url
         }}

      {:error, reason} ->
        Logger.error("FixFilesErrors: Failed - #{inspect(reason)}")
        {:error, "Error fixing failed: #{inspect(reason)}"}
    end
  end

  defp build_user_message(args) do
    component_name = Map.get(args, "componentName")
    files_created = Map.get(args, "filesCreated", [])
    test_page_url = Map.get(args, "testPageUrl")

    files_str = Enum.map_join(files_created, "\n", &"  - #{&1}")

    task_text = """
    ## Fix Component Errors

    - **Component:** #{component_name}
    - **Test Page URL:** #{test_page_url}

    ## Files to Check

    #{files_str}

    ## Instructions

    1. Navigate to the test page at `#{test_page_url}`
    2. Use `get_errors` to check for any errors
    3. Fix any errors found in the component files
    4. Repeat until no errors remain (max 5 iterations)
    5. Use `navigate_back` to leave the test page
    6. Return the result as JSON
    """

    Message.user(task_text)
  end
end
