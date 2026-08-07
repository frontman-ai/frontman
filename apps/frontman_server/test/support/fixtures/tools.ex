defmodule FrontmanServer.Test.Fixtures.Tools do
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.MCP

  def tool_context(task) do
    %Context{task: task}
  end

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
