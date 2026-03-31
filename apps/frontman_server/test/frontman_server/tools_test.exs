defmodule FrontmanServer.ToolsTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.TodoWrite

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "tools_test_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    task_id = Ecto.UUID.generate()
    {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")
    {:ok, task} = Tasks.get_task(scope, task_id)
    {:ok, task_id: task_id, task: task, scope: scope}
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
    test "finds existing tool" do
      assert {:ok, module} = Tools.find_tool("todo_write")
      assert module == TodoWrite
    end

    test "finds web_fetch tool" do
      assert {:ok, module} = Tools.find_tool("web_fetch")
      assert module == FrontmanServer.Tools.WebFetch
    end

    test "returns :not_found for non-existent tool" do
      assert :not_found = Tools.find_tool("nonexistent")
    end

    test "returns :not_found for old todo tools" do
      assert :not_found = Tools.find_tool("todo_add")
      assert :not_found = Tools.find_tool("todo_update")
      assert :not_found = Tools.find_tool("todo_remove")
      assert :not_found = Tools.find_tool("todo_list")
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

  defp build_context(scope, task) do
    %Context{
      scope: scope,
      task: task,
      tool_executor: fn tool_calls ->
        Enum.map(tool_calls, fn tc -> SwarmAi.ToolResult.make(tc.id, "mock result", false) end)
      end,
      llm_opts: [api_key: "test-key", model: "openrouter:anthropic/claude-sonnet-4-20250514"]
    }
  end

  describe "TodoWrite.execute/2" do
    test "writes a valid todo list", %{task: task, scope: scope} do
      context = build_context(scope, task)

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

      assert {:ok, %{"todos" => todos}} = TodoWrite.execute(args, context)
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

    test "accepts empty todos array", %{task: task, scope: scope} do
      context = build_context(scope, task)
      assert {:ok, %{"todos" => []}} = TodoWrite.execute(%{"todos" => []}, context)
    end

    test "rejects invalid status", %{task: task, scope: scope} do
      context = build_context(scope, task)

      args = %{
        "todos" => [
          %{
            "content" => "Task",
            "active_form" => "Working",
            "status" => "invalid_status"
          }
        ]
      }

      assert {:error, msg} = TodoWrite.execute(args, context)
      assert msg =~ "index 0"
    end

    test "rejects invalid priority", %{task: task, scope: scope} do
      context = build_context(scope, task)

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

      assert {:error, msg} = TodoWrite.execute(args, context)
      assert msg =~ "index 0"
    end

    test "rejects missing required fields", %{task: task, scope: scope} do
      context = build_context(scope, task)

      args = %{
        "todos" => [
          %{"content" => "Task"}
        ]
      }

      assert {:error, _} = TodoWrite.execute(args, context)
    end
  end
end
