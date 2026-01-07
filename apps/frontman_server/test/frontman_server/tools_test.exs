defmodule FrontmanServer.ToolsTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Todos.Todo
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.TodoAdd
  alias FrontmanServer.Tools.TodoList
  alias FrontmanServer.Tools.TodoRemove
  alias FrontmanServer.Tools.TodoUpdate

  setup do
    task_id = "test_task_#{:rand.uniform(1_000_000)}"
    {:ok, ^task_id} = Tasks.create_task(task_id)
    {:ok, task} = Tasks.get_task(task_id)
    {:ok, task_id: task_id, task: task}
  end

  describe "backend_tools/0" do
    test "all tools have proper structure" do
      tools = Tools.backend_tools()

      Enum.each(tools, fn tool ->
        assert %Swarm.Tool{} = tool
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

  describe "todo_mutation?/1" do
    test "returns true for todo mutation tools" do
      assert Tools.todo_mutation?("todo_add")
      assert Tools.todo_mutation?("todo_update")
      assert Tools.todo_mutation?("todo_remove")
    end

    test "returns false for non-mutation tools" do
      refute Tools.todo_mutation?("todo_list")
      refute Tools.todo_mutation?("breakdown_figma_design")
      refute Tools.todo_mutation?("some_mcp_tool")
    end
  end

  # Note: execute_backend_tool/2 functionality moved to ToolExecutor.execute/3

  describe "tool execution via module.execute/2" do
    test "todo_add returns Todo struct", %{task: task} do
      context = %Context{task: task}

      result =
        TodoAdd.execute(
          %{"content" => "Test todo", "active_form" => "Testing todo"},
          context
        )

      assert {:ok, %Todo{} = todo} = result
      assert todo.content == "Test todo"
      assert todo.status == :pending
    end

    test "todo_list returns todos after adding", %{task_id: task_id} do
      {:ok, task} = Tasks.get_task(task_id)
      context = %Context{task: task}

      # Add a todo
      {:ok, todo} =
        TodoAdd.execute(
          %{"content" => "Test", "active_form" => "Testing"},
          context
        )

      # Store the result
      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, todo, false)

      # Refresh task to get updated interactions
      {:ok, updated_task} = Tasks.get_task(task_id)
      updated_context = %Context{task: updated_task}

      # List todos
      {:ok, result} = TodoList.execute(%{}, updated_context)
      assert %{"todos" => todos} = result
      assert length(todos) == 1
    end

    test "todo_update returns updated Todo", %{task_id: task_id} do
      {:ok, task} = Tasks.get_task(task_id)
      context = %Context{task: task}

      # Add a todo
      {:ok, todo} =
        TodoAdd.execute(
          %{"content" => "Test", "active_form" => "Testing"},
          context
        )

      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, todo, false)

      # Refresh task to get updated interactions
      {:ok, updated_task} = Tasks.get_task(task_id)
      updated_context = %Context{task: updated_task}

      # Update it
      {:ok, %Todo{} = updated} =
        TodoUpdate.execute(
          %{"id" => todo.id, "status" => "completed"},
          updated_context
        )

      assert updated.status == :completed
    end

    test "todo_remove returns todo_id", %{task_id: task_id} do
      {:ok, task} = Tasks.get_task(task_id)
      context = %Context{task: task}

      # Add a todo
      {:ok, todo} =
        TodoAdd.execute(
          %{"content" => "Test", "active_form" => "Testing"},
          context
        )

      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, todo, false)

      # Refresh task to get updated interactions
      {:ok, updated_task} = Tasks.get_task(task_id)
      updated_context = %Context{task: updated_task}

      # Remove it
      {:ok, removed_id} =
        TodoRemove.execute(%{"id" => todo.id}, updated_context)

      assert removed_id == todo.id
    end
  end
end
