defmodule FrontmanServer.ToolsTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction.ToolResult
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.GetToolResult
  alias FrontmanServer.Tools.TodoWrite
  alias FrontmanServer.Tools.WebFetch
  alias ModelContextProtocol, as: MCP

  setup do
    scope = user_scope_fixture()
    task_id = task_with_active_run_fixture(scope, framework: "nextjs").id
    {:ok, task} = Tasks.get_task(scope, task_id)
    {:ok, task_id: task_id, task: task, scope: scope, turn_number: latest_turn_number(task_id)}
  end

  describe "backend_tools/0" do
    test "all tools have proper structure" do
      tools = Tools.backend_tools()

      Enum.each(tools, fn tool ->
        assert %SwarmAi.Tool{} = tool
        assert is_binary(tool.name)
        assert is_binary(tool.description)
        assert is_map(tool.parameter_schema)
      end)
    end
  end

  describe "find_tool/1" do
    test "finds registered tools" do
      for {tool_name, module} <- [
            {"todo_write", TodoWrite},
            {"get_tool_result", GetToolResult},
            {"web_fetch", WebFetch}
          ] do
        assert Tools.find_tool(tool_name) == {:ok, module}
      end
    end

    test "returns :not_found for unavailable tools" do
      for tool_name <- ~w(nonexistent todo_add todo_update todo_remove todo_list) do
        assert Tools.find_tool(tool_name) == :not_found
      end
    end
  end

  describe "execution_target/1" do
    test "returns :backend for backend tools" do
      Tools.backend_tools()
      |> Enum.each(fn tool ->
        assert Tools.execution_target(tool.name) == :backend,
               "Expected #{tool.name} to target :backend"
      end)
    end

    test "returns :mcp for non-backend tools" do
      assert Tools.execution_target("read_file") == :mcp
      assert Tools.execution_target("screenshot") == :mcp
      assert Tools.execution_target("unknown_tool") == :mcp
      assert Tools.execution_target("question") == :mcp
      assert Tools.execution_target("") == :mcp
    end
  end

  describe "todo_mutation?/1" do
    test "returns true for todo_write" do
      assert Tools.todo_mutation?("todo_write")
    end

    test "returns false for old todo tools and other tools" do
      refute Tools.todo_mutation?("todo_add")
      refute Tools.todo_mutation?("todo_update")
      refute Tools.todo_mutation?("todo_remove")
      refute Tools.todo_mutation?("todo_list")
      refute Tools.todo_mutation?("some_mcp_tool")
    end
  end

  defp build_context(task) do
    %Context{task: task}
  end

  describe "TodoWrite.execute/2" do
    test "writes a valid todo list", %{task: task} do
      context = build_context(task)

      args = %{
        "todos" => [
          %{
            "content" => "Fix bug",
            "active_form" => "Fixing bug",
            "status" => "pending",
            "priority" => "high"
          },
          %{
            "content" => "Write tests",
            "active_form" => "Writing tests",
            "status" => "in_progress"
          }
        ]
      }

      result = TodoWrite.execute(args, context)
      refute MCP.error?(result)
      assert %{"todos" => todos} = result["structuredContent"]
      assert Jason.decode!(MCP.extract_content_text(result)) == result["structuredContent"]
      assert length(todos) == 2

      [first, second] = todos
      assert first["content"] == "Fix bug"
      assert first["priority"] == "high"
      assert first["status"] == "pending"
      assert is_binary(first["id"])

      assert second["content"] == "Write tests"
      # default priority
      assert second["priority"] == "medium"
      assert second["status"] == "in_progress"
    end

    test "accepts empty todos array", %{task: task} do
      context = build_context(task)

      assert %{"structuredContent" => %{"todos" => []}} =
               TodoWrite.execute(%{"todos" => []}, context)
    end

    test "rejects invalid status", %{task: task} do
      context = build_context(task)

      args = %{
        "todos" => [
          %{
            "content" => "Task",
            "active_form" => "Working",
            "status" => "invalid_status"
          }
        ]
      }

      result = TodoWrite.execute(args, context)
      assert MCP.error?(result)
      msg = MCP.extract_content_text(result)
      assert msg =~ "index 0"
    end

    test "rejects invalid priority", %{task: task} do
      context = build_context(task)

      args = %{
        "todos" => [
          %{
            "content" => "Task",
            "active_form" => "Working",
            "status" => "pending",
            "priority" => "critical"
          }
        ]
      }

      result = TodoWrite.execute(args, context)
      assert MCP.error?(result)
      msg = MCP.extract_content_text(result)
      assert msg =~ "index 0"
    end

    test "rejects missing required fields", %{task: task} do
      context = build_context(task)

      args = %{
        "todos" => [
          %{"content" => "Task"}
        ]
      }

      assert TodoWrite.execute(args, context) |> MCP.error?()
    end
  end

  describe "GetToolResult.execute/2" do
    test "returns the actual tool result by tool call ID", %{
      task_id: task_id,
      scope: scope,
      turn_number: turn_number
    } do
      stored_result = MCP.tool_result_text("file contents")

      {:ok, interaction, :no_executor} =
        Tasks.resolve_tool_request(
          scope,
          task_id,
          %{id: "tc-read", name: "read_file"},
          stored_result,
          false,
          turn_number: turn_number
        )

      {:ok, task} = Tasks.get_task(scope, task_id)
      context = build_context(task)

      result = GetToolResult.execute(%{"tool_call_id" => "tc-read"}, context)

      assert result == stored_result
      assert interaction.tool_call_id == "tc-read"
    end

    test "returns an error when the interaction does not exist", %{task: task} do
      context = build_context(task)

      result = GetToolResult.execute(%{"tool_call_id" => "missing"}, context)
      assert MCP.error?(result)
      assert MCP.extract_content_text(result) == "Tool result not found: missing"
    end

    test "returns an error when the stored result is malformed", %{task: task} do
      malformed_result =
        %ToolResult{
          id: Ecto.UUID.generate(),
          tool_call_id: "tc-malformed",
          tool_name: "read_file",
          result: %{"content" => "tool result text"},
          is_error: false,
          timestamp: DateTime.utc_now()
        }

      context = build_context(%{task | interactions: [malformed_result | task.interactions]})

      result = GetToolResult.execute(%{"tool_call_id" => "tc-malformed"}, context)

      assert MCP.error?(result)

      assert MCP.extract_content_text(result) ==
               "Stored tool result for tc-malformed is not a valid MCP tool result"
    end

    test "returns an error when content is invalid type", %{task: task} do
      malformed_result =
        %ToolResult{
          id: Ecto.UUID.generate(),
          tool_call_id: "tc-invalid-content",
          tool_name: "read_file",
          result: %{"content" => [%{"type" => "text", "text" => "ok"}, "bad"], "isError" => false},
          is_error: false,
          timestamp: DateTime.utc_now()
        }

      context = build_context(%{task | interactions: [malformed_result | task.interactions]})

      result = GetToolResult.execute(%{"tool_call_id" => "tc-invalid-content"}, context)

      assert MCP.error?(result)

      assert MCP.extract_content_text(result) ==
               "Stored tool result is invalid: content must be list of objects"
    end
  end
end
