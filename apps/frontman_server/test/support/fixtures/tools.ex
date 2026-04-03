defmodule FrontmanServer.Test.Fixtures.Tools do
  @moduledoc """
  Reusable fixtures for tool integration tests.

  Provides generic helpers for setting up tool execution contexts and
  managing task interactions.

  ## Usage

      import FrontmanServer.Test.Fixtures.Tools

      setup %{task: task} do
        context = tool_context(task)
        {:ok, context: context}
      end
  """

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.Backend.Context

  @doc """
  Build a tool execution context.

  Generic helper for creating a Context struct with the standard fields
  needed for tool execution. Includes a no-op executor for testing and
  default llm_opts.
  """
  @spec tool_context(FrontmanServer.Accounts.Scope.t(), map(), keyword()) :: Context.t()
  def tool_context(scope, task, llm_opts \\ []) do
    # No-op executor for tests that don't actually execute sub-agents
    noop_executor = fn tool_calls ->
      Enum.map(tool_calls, fn tc ->
        SwarmAi.ToolResult.make(tc.id, "mock result", false)
      end)
    end

    # Merge default llm_opts with any provided options (e.g., fixture_path)
    # Use a model that exists in LLMDB - matches the model used when fixtures were recorded
    default_llm_opts = [
      api_key: "test-api-key",
      model: "openrouter:anthropic/claude-haiku-4.5"
    ]

    merged_llm_opts = Keyword.merge(default_llm_opts, llm_opts)

    %Context{scope: scope, task: task, tool_executor: noop_executor, llm_opts: merged_llm_opts}
  end

  @doc """
  Add a markdown file to task interactions.

  Simulates the task having read a markdown file via read_file tool,
  making it available for injection into sub-agent context.
  """
  @spec add_markdown_to_task(
          FrontmanServer.Accounts.Scope.t(),
          String.t(),
          String.t(),
          String.t()
        ) :: :ok
  def add_markdown_to_task(scope, task_id, filename, content) do
    tool_call = %{
      id: "call_#{:rand.uniform(1_000_000)}",
      name: "read_file"
    }

    result = %{"path" => filename, "text" => content}
    Tasks.add_tool_result(scope, task_id, tool_call, result, false)
  end

  @doc """
  Structured question tool input for interactive tool tests.
  """
  @spec question_args() :: map()
  def question_args do
    %{
      "questions" => [
        %{
          "question" => "Pick one",
          "header" => "Test",
          "options" => [%{"label" => "A", "description" => "Option A"}]
        }
      ]
    }
  end

  @doc """
  MCP tool definition list for the interactive `question` tool.
  """
  @spec question_mcp_tool_defs() :: [FrontmanServer.Tools.MCP.t()]
  def question_mcp_tool_defs do
    alias FrontmanServer.Tools.MCP

    [
      %MCP{
        name: "question",
        description: "Ask the user a question",
        input_schema: %{
          "type" => "object",
          "properties" => %{"questions" => %{"type" => "array"}}
        },
        visible_to_agent: true,
        execution_mode: :interactive
      }
    ]
  end
end
