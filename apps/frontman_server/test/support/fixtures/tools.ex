defmodule FrontmanServer.Test.Fixtures.Tools do
  @moduledoc """
  Reusable fixtures for tool integration tests.

  Provides generic helpers for setting up tool execution contexts and
  managing task interactions.

  ## Usage

      import FrontmanServer.Test.Fixtures.Tools

      setup %{task: task, llm_opts: llm_opts} do
        context = tool_context(task, llm_opts)
        {:ok, context: context}
      end
  """

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.Backend.Context

  @doc """
  Build a tool execution context.

  Generic helper for creating a Context struct with the standard fields
  needed for tool execution. Includes a no-op executor for testing.
  """
  @spec tool_context(map(), keyword()) :: Context.t()
  def tool_context(task, llm_opts) do
    # No-op executor for tests that don't actually execute sub-agents
    noop_executor = fn _tool_call -> {:ok, "mock result"} end
    %Context{task: task, tool_executor: noop_executor, llm_opts: llm_opts}
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
end
