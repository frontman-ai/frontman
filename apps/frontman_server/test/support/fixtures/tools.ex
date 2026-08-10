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

  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.MCP

  @doc """
  Build a tool execution context.
  """
  def tool_context(task) do
    %Context{task: task}
  end

  @doc """
  Structured question tool input for interactive tool tests.
  """
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
  Structured todo_write tool input for backend tool tests.
  """
  def todo_args do
    %{
      "todos" => [
        %{
          "content" => "Fix the bug",
          "active_form" => "Fixing the bug",
          "status" => "pending",
          "priority" => "medium"
        }
      ]
    }
  end

  @doc """
  MCP tool definition list for the interactive `question` tool.

  The interactive timeout behavior is an internal execution policy.
  """
  def question_mcp_tool_defs do
    [
      %MCP{
        name: "question",
        description: "Ask the user a question",
        input_schema: %{
          "type" => "object",
          "properties" => %{"questions" => %{"type" => "array"}}
        },
        timeout_ms: 120_000,
        on_timeout: :pause_agent
      }
    ]
  end
end
