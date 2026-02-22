defmodule FrontmanServer.ToolsTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Todos.Todo
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.TodoAdd
  alias FrontmanServer.Tools.TodoList
  alias FrontmanServer.Tools.TodoRemove
  alias FrontmanServer.Tools.TodoUpdate

  setup do
    # Create a test user for scope
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
      assert {:ok, module} = Tools.find_tool("todo_list")
      assert module == TodoList
    end

    test "returns :not_found for non-existent tool" do
      assert :not_found = Tools.find_tool("nonexistent")
    end
  end

  describe "execution_target/1" do
    test "returns :backend for all registered backend tools" do
      Tools.backend_tools()
      |> Enum.each(fn tool ->
        assert Tools.execution_target(tool.name) == :backend,
               "Expected #{tool.name} to target :backend"
      end)
    end

    test "returns :mcp for non-backend tools" do
      # These aren't in @backend_tools, so they route to MCP
      assert Tools.execution_target("read_file") == :mcp
      assert Tools.execution_target("screenshot") == :mcp
      assert Tools.execution_target("unknown_tool") == :mcp
      assert Tools.execution_target("") == :mcp
    end
  end

  describe "todo_mutation?/1" do
    test "returns true for todo mutation tools" do
      assert Tools.todo_mutation?("todo_add")
      assert Tools.todo_mutation?("todo_update")
      assert Tools.todo_mutation?("todo_remove")
    end

    test "returns false for non-mutation tools" do
      refute Tools.todo_mutation?("todo_list")
      refute Tools.todo_mutation?("some_mcp_tool")
    end
  end

  # Note: execute_backend_tool/2 functionality moved to ToolExecutor.execute/3

  # Build a test context with required fields
  defp build_context(scope, task) do
    %Context{
      scope: scope,
      task: task,
      tool_executor: fn _tool_call -> {:ok, "mock result"} end,
      llm_opts: [api_key: "test-key", model: "openrouter:anthropic/claude-sonnet-4-20250514"]
    }
  end

  describe "tool execution via module.execute/2" do
    test "todo_add returns Todo struct", %{task: task, scope: scope} do
      context = build_context(scope, task)

      result =
        TodoAdd.execute(
          %{"content" => "Test todo", "active_form" => "Testing todo"},
          context
        )

      assert {:ok, %Todo{} = todo} = result
      assert todo.content == "Test todo"
      assert todo.status == :pending
    end

    test "todo_list returns todos after adding", %{task_id: task_id, scope: scope} do
      {:ok, task} = Tasks.get_task(scope, task_id)
      context = build_context(scope, task)

      # Add a todo
      {:ok, todo} =
        TodoAdd.execute(
          %{"content" => "Test", "active_form" => "Testing"},
          context
        )

      # Store the result
      Tasks.add_tool_result(scope, task_id, %{id: "call1", name: "todo_add"}, todo, false)

      # Refresh task to get updated interactions
      {:ok, updated_task} = Tasks.get_task(scope, task_id)
      updated_context = build_context(scope, updated_task)

      # List todos
      {:ok, result} = TodoList.execute(%{}, updated_context)
      assert %{"todos" => todos} = result
      assert length(todos) == 1
    end

    test "todo_update returns updated Todo", %{task_id: task_id, scope: scope} do
      {:ok, task} = Tasks.get_task(scope, task_id)
      context = build_context(scope, task)

      # Add a todo
      {:ok, todo} =
        TodoAdd.execute(
          %{"content" => "Test", "active_form" => "Testing"},
          context
        )

      Tasks.add_tool_result(scope, task_id, %{id: "call1", name: "todo_add"}, todo, false)

      # Refresh task to get updated interactions
      {:ok, updated_task} = Tasks.get_task(scope, task_id)
      updated_context = build_context(scope, updated_task)

      # Update it
      {:ok, %Todo{} = updated} =
        TodoUpdate.execute(
          %{"id" => todo.id, "status" => "completed"},
          updated_context
        )

      assert updated.status == :completed
    end

    test "todo_remove returns todo_id", %{task_id: task_id, scope: scope} do
      {:ok, task} = Tasks.get_task(scope, task_id)
      context = build_context(scope, task)

      # Add a todo
      {:ok, todo} =
        TodoAdd.execute(
          %{"content" => "Test", "active_form" => "Testing"},
          context
        )

      Tasks.add_tool_result(scope, task_id, %{id: "call1", name: "todo_add"}, todo, false)

      # Refresh task to get updated interactions
      {:ok, updated_task} = Tasks.get_task(scope, task_id)
      updated_context = build_context(scope, updated_task)

      # Remove it
      {:ok, removed_id} =
        TodoRemove.execute(%{"id" => todo.id}, updated_context)

      assert removed_id == todo.id
    end
  end
end
