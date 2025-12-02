defmodule FrontmanServer.ToolsTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tools
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction.ToolCall

  setup do
    task_id = "test_task_#{:rand.uniform(1000000)}"
    {:ok, ^task_id} = Tasks.create_task(task_id)
    {:ok, task_id: task_id}
  end

  describe "backend_tools/1" do
    test "returns 4 backend tools", %{task_id: task_id} do
      tools = Tools.backend_tools(task_id)
      assert length(tools) == 4

      tool_names = Enum.map(tools, & &1.name)
      assert "todo_list" in tool_names
      assert "todo_add" in tool_names
      assert "todo_update" in tool_names
      assert "todo_remove" in tool_names
    end

    test "all tools have proper structure", %{task_id: task_id} do
      tools = Tools.backend_tools(task_id)

      Enum.each(tools, fn tool ->
        assert is_binary(tool.name)
        assert is_binary(tool.description)
        assert is_map(tool.parameter_schema)
        assert is_function(tool.callback)
      end)
    end
  end

  describe "find_backend_tool/2" do
    test "finds existing tool", %{task_id: task_id} do
      assert {:ok, tool} = Tools.find_backend_tool("todo_list", task_id)
      assert tool.name == "todo_list"
    end

    test "returns :not_found for non-existent tool", %{task_id: task_id} do
      assert :not_found = Tools.find_backend_tool("nonexistent", task_id)
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

  describe "tool execution" do
    test "todo_add tool callback works", %{task_id: task_id} do
      {:ok, tool} = Tools.find_backend_tool("todo_add", task_id)

      result = tool.callback.(%{
        "content" => "Test todo",
        "active_form" => "Testing todo"
      })

      assert {:ok, %FrontmanServer.Tasks.Todos.Tools.TodoAdded{} = event} = result
      assert event.content == "Test todo"
      assert event.status == :pending
    end

    test "todo_list tool callback works", %{task_id: task_id} do
      {:ok, add_tool} = Tools.find_backend_tool("todo_add", task_id)
      {:ok, %FrontmanServer.Tasks.Todos.Tools.TodoAdded{} = event} = add_tool.callback.(%{
        "content" => "Test",
        "active_form" => "Testing"
      })
      {:ok, _interaction} = Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, event, false)

      {:ok, task} = Tasks.get_task(task_id)
      assert length(task.interactions) == 1

      [interaction] = task.interactions
      assert %FrontmanServer.Tasks.Interaction.ToolResult{} = interaction
      assert %FrontmanServer.Tasks.Todos.Tools.TodoAdded{} = interaction.result

      {:ok, list_tool} = Tools.find_backend_tool("todo_list", task_id)
      {:ok, result} = list_tool.callback.(%{})
      assert %{"todos" => todos} = result
      assert length(todos) == 1
    end

    test "todo_update tool callback works", %{task_id: task_id} do
      {:ok, add_tool} = Tools.find_backend_tool("todo_add", task_id)
      {:ok, %FrontmanServer.Tasks.Todos.Tools.TodoAdded{} = add_event} = add_tool.callback.(%{
        "content" => "Test",
        "active_form" => "Testing"
      })

      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, add_event, false)

      {:ok, update_tool} = Tools.find_backend_tool("todo_update", task_id)
      {:ok, %FrontmanServer.Tasks.Todos.Tools.TodoUpdated{} = update_event} = update_tool.callback.(%{
        "id" => add_event.todo_id,
        "status" => "completed"
      })

      assert update_event.status == :completed

      Tasks.add_tool_result(task_id, %{id: "call2", name: "todo_update"}, update_event, false)

      {:ok, list_tool} = Tools.find_backend_tool("todo_list", task_id)
      {:ok, %{"todos" => todos}} = list_tool.callback.(%{})
      updated_todo = Enum.find(todos, &(&1["id"] == add_event.todo_id))
      assert updated_todo["status"] == "completed"
    end

    test "todo_remove tool callback works", %{task_id: task_id} do
      {:ok, add_tool} = Tools.find_backend_tool("todo_add", task_id)
      {:ok, %FrontmanServer.Tasks.Todos.Tools.TodoAdded{} = add_event} = add_tool.callback.(%{
        "content" => "Test",
        "active_form" => "Testing"
      })

      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, add_event, false)

      {:ok, remove_tool} = Tools.find_backend_tool("todo_remove", task_id)
      {:ok, %FrontmanServer.Tasks.Todos.Tools.TodoRemoved{} = remove_event} = remove_tool.callback.(%{"id" => add_event.todo_id})

      Tasks.add_tool_result(task_id, %{id: "call2", name: "todo_remove"}, remove_event, false)

      {:ok, list_tool} = Tools.find_backend_tool("todo_list", task_id)
      {:ok, %{"todos" => todos}} = list_tool.callback.(%{})
      assert Enum.empty?(todos)
    end
  end
end
