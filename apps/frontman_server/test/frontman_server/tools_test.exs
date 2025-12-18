defmodule FrontmanServer.ToolsTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction.ToolCall
  alias FrontmanServer.Tasks.Todos.Todo

  setup do
    task_id = "test_task_#{:rand.uniform(1_000_000)}"
    agent_id = "agent_#{:rand.uniform(1_000_000)}"
    {:ok, ^task_id} = Tasks.create_task(task_id)
    {:ok, task} = Tasks.get_task(task_id)
    {:ok, task_id: task_id, agent_id: agent_id, task: task}
  end

  describe "backend_tools/0" do
    test "returns 6 backend tools (4 todo + 2 figma)" do
      tools = Tools.backend_tools()
      assert length(tools) == 6

      tool_names = Enum.map(tools, & &1.name)
      assert "todo_list" in tool_names
      assert "todo_add" in tool_names
      assert "todo_update" in tool_names
      assert "todo_remove" in tool_names
      assert "breakdown_figma_node" in tool_names
      assert "implement_component" in tool_names
    end

    test "all tools have proper structure" do
      tools = Tools.backend_tools()

      Enum.each(tools, fn tool ->
        assert is_binary(tool.name)
        assert is_binary(tool.description)
        assert is_map(tool.parameter_schema)
        assert is_function(tool.callback)
      end)
    end
  end

  describe "find_tool/1" do
    test "finds existing tool" do
      assert {:ok, module} = Tools.find_tool("todo_list")
      assert module == FrontmanServer.Tools.TodoList
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
      refute Tools.todo_mutation?("breakdown_figma_node")
      refute Tools.todo_mutation?("some_mcp_tool")
    end
  end

  describe "execute_backend_tool/2" do
    test "executes backend tool successfully", %{task_id: task_id} do
      tool_call = %ToolCall{
        id: "call_123",
        agent_id: "agent_456",
        tool_call_id: "call_123",
        tool_name: "todo_list",
        arguments: %{},
        timestamp: DateTime.utc_now()
      }

      assert {:executed, {:ok, result}} = Tools.execute_backend_tool(tool_call, task_id)
      assert %{"todos" => []} = result
    end

    test "returns :not_found for non-backend tool", %{task_id: task_id} do
      tool_call = %ToolCall{
        id: "call_123",
        agent_id: "agent_456",
        tool_call_id: "call_123",
        tool_name: "some_mcp_tool",
        arguments: %{},
        timestamp: DateTime.utc_now()
      }

      assert :not_found = Tools.execute_backend_tool(tool_call, task_id)
    end

    test "handles tool execution errors", %{task_id: task_id} do
      tool_call = %ToolCall{
        id: "call_123",
        agent_id: "agent_456",
        tool_call_id: "call_123",
        tool_name: "todo_update",
        arguments: %{"id" => "nonexistent", "status" => "completed"},
        timestamp: DateTime.utc_now()
      }

      assert {:executed, {:error, _message}} = Tools.execute_backend_tool(tool_call, task_id)
    end
  end

  describe "tool execution via module.execute/2" do
    test "todo_add returns Todo struct", %{task: task, agent_id: agent_id} do
      context = %Context{task: task, agent_id: agent_id}

      result =
        FrontmanServer.Tools.TodoAdd.execute(
          %{"content" => "Test todo", "active_form" => "Testing todo"},
          context
        )

      assert {:ok, %Todo{} = todo} = result
      assert todo.content == "Test todo"
      assert todo.status == :pending
    end

    test "todo_list returns todos after adding", %{task_id: task_id, agent_id: agent_id} do
      {:ok, task} = Tasks.get_task(task_id)
      context = %Context{task: task, agent_id: agent_id}

      # Add a todo
      {:ok, todo} =
        FrontmanServer.Tools.TodoAdd.execute(
          %{"content" => "Test", "active_form" => "Testing"},
          context
        )

      # Store the result
      Tasks.add_tool_result(task_id, agent_id, %{id: "call1", name: "todo_add"}, todo, false)

      # Refresh task to get updated interactions
      {:ok, updated_task} = Tasks.get_task(task_id)
      updated_context = %Context{task: updated_task, agent_id: agent_id}

      # List todos
      {:ok, result} = FrontmanServer.Tools.TodoList.execute(%{}, updated_context)
      assert %{"todos" => todos} = result
      assert length(todos) == 1
    end

    test "todo_update returns updated Todo", %{task_id: task_id, agent_id: agent_id} do
      {:ok, task} = Tasks.get_task(task_id)
      context = %Context{task: task, agent_id: agent_id}

      # Add a todo
      {:ok, todo} =
        FrontmanServer.Tools.TodoAdd.execute(
          %{"content" => "Test", "active_form" => "Testing"},
          context
        )

      Tasks.add_tool_result(task_id, agent_id, %{id: "call1", name: "todo_add"}, todo, false)

      # Refresh task to get updated interactions
      {:ok, updated_task} = Tasks.get_task(task_id)
      updated_context = %Context{task: updated_task, agent_id: agent_id}

      # Update it
      {:ok, %Todo{} = updated} =
        FrontmanServer.Tools.TodoUpdate.execute(
          %{"id" => todo.id, "status" => "completed"},
          updated_context
        )

      assert updated.status == :completed
    end

    test "todo_remove returns todo_id", %{task_id: task_id, agent_id: agent_id} do
      {:ok, task} = Tasks.get_task(task_id)
      context = %Context{task: task, agent_id: agent_id}

      # Add a todo
      {:ok, todo} =
        FrontmanServer.Tools.TodoAdd.execute(
          %{"content" => "Test", "active_form" => "Testing"},
          context
        )

      Tasks.add_tool_result(task_id, agent_id, %{id: "call1", name: "todo_add"}, todo, false)

      # Refresh task to get updated interactions
      {:ok, updated_task} = Tasks.get_task(task_id)
      updated_context = %Context{task: updated_task, agent_id: agent_id}

      # Remove it
      {:ok, removed_id} =
        FrontmanServer.Tools.TodoRemove.execute(%{"id" => todo.id}, updated_context)

      assert removed_id == todo.id
    end
  end
end
