defmodule FrontmanServer.Test.Fixtures.Tools do
  @moduledoc """
  Reusable fixtures for tool integration tests.

  Provides generic helpers for setting up tool execution contexts and
  managing task interactions.

  ## Usage

      import FrontmanServer.Test.Fixtures.Tools

      setup %{task: task, agent_id: agent_id, llm_opts: llm_opts} do
        context = tool_context(task, agent_id, llm_opts)
        {:ok, context: context}
      end
  """

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools.Backend.Context

  @doc """
  Build a tool execution context.

  Generic helper for creating a Context struct with the standard fields
  needed for tool execution.
  """
  @spec tool_context(map(), String.t(), keyword()) :: Context.t()
  def tool_context(task, agent_id, llm_opts) do
    %Context{task: task, agent_id: agent_id, llm_opts: llm_opts}
  end

  @doc """
  Add a markdown file to task interactions.

  Simulates the task having read a markdown file via read_file tool,
  making it available for injection into sub-agent context.
  """
  @spec add_markdown_to_task(String.t(), String.t(), String.t()) :: :ok
  def add_markdown_to_task(task_id, filename, content) do
    tool_call = %{
      id: "call_#{:rand.uniform(1_000_000)}",
      name: "read_file"
    }

    result = %{"path" => filename, "text" => content}
    Tasks.add_tool_result(task_id, "setup_agent", tool_call, result, false)
  end
end
