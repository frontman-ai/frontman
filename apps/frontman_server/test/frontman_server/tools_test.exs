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
      assert %{"type" => "todo_list", "todos" => []} = result
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

      assert {:ok, %{"type" => "todo_add", "todo" => todo}} = result
      assert todo["content"] == "Test todo"
      assert todo["status"] == "pending"
    end

    test "todo_list tool callback works", %{task_id: task_id} do
      # Add a todo first via Tasks API
      {:ok, todo} = Tasks.create_todo("Test", "Testing")
      result = Jason.encode!(%{"type" => "todo_add", "todo" => serialize_todo(todo)})
      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, result, false)

      # List todos
      {:ok, list_tool} = Tools.find_backend_tool("todo_list", task_id)
      result = list_tool.callback.(%{})

      assert {:ok, %{"type" => "todo_list", "todos" => todos}} = result
      assert length(todos) == 1
    end

    test "todo_update tool callback works", %{task_id: task_id} do
      # Add a todo
      {:ok, add_tool} = Tools.find_backend_tool("todo_add", task_id)
      {:ok, %{"todo" => todo}} = add_tool.callback.(%{
        "content" => "Test",
        "active_form" => "Testing"
      })

      # Store it as a tool result so it exists in the event log
      result = Jason.encode!(%{"type" => "todo_add", "todo" => todo})
      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, result, false)

      # Update it
      {:ok, update_tool} = Tools.find_backend_tool("todo_update", task_id)
      result = update_tool.callback.(%{
        "id" => todo["id"],
        "status" => "completed"
      })

      assert {:ok, %{"type" => "todo_update", "todo" => updated}} = result
      assert updated["status"] == "completed"
    end

    test "todo_remove tool callback works", %{task_id: task_id} do
      # Add a todo
      {:ok, add_tool} = Tools.find_backend_tool("todo_add", task_id)
      {:ok, %{"todo" => todo}} = add_tool.callback.(%{
        "content" => "Test",
        "active_form" => "Testing"
      })

      # Store it as a tool result
      result = Jason.encode!(%{"type" => "todo_add", "todo" => todo})
      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, result, false)

      # Remove it
      {:ok, remove_tool} = Tools.find_backend_tool("todo_remove", task_id)
      result = remove_tool.callback.(%{"id" => todo["id"]})

      assert {:ok, %{"type" => "todo_remove"}} = result
    end
  end

  defp serialize_todo(todo) do
    %{
      "id" => todo.id,
      "content" => todo.content,
      "active_form" => todo.active_form,
      "status" => todo.status,
      "created_at" => DateTime.to_iso8601(todo.created_at),
      "updated_at" => DateTime.to_iso8601(todo.updated_at)
    }
  end
end
