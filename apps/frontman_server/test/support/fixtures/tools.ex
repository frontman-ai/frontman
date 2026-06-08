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

  Derived from wire-format data via MCP.from_map/1 so that changes to
  the parsing layer are caught by tests that use this fixture.
  """
  def question_mcp_tool_defs do
    MCP.from_maps([
      %{
        "name" => "question",
        "description" => "Ask the user a question",
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{"questions" => %{"type" => "array"}}
        },
        "executionMode" => "interactive"
      }
    ])
  end
end
