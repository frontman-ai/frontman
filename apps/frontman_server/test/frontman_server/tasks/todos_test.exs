defmodule FrontmanServer.Tasks.TodosTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Todos
  alias FrontmanServer.Tasks.Todos.Todo

  setup do
    # Create a task for testing
    task_id = "test_task_#{:rand.uniform(1000000)}"
    {:ok, ^task_id} = Tasks.create_task(task_id)

    {:ok, task_id: task_id}
  end

  describe "list_todos/1" do
    test "returns empty list for empty interactions", %{task_id: task_id} do
      {:ok, task} = Tasks.get_task(task_id)
      assert [] = Todos.list_todos(task.interactions)
    end
  end

  describe "create_todo/3" do
    test "creates a todo with default status" do
      assert {:ok, todo} = Todos.create_todo("Fix bug", "Fixing bug")
      assert todo.content == "Fix bug"
      assert todo.active_form == "Fixing bug"
      assert todo.status == "pending"
      assert %DateTime{} = todo.created_at
      assert %DateTime{} = todo.updated_at
      assert is_binary(todo.id)
    end

    test "creates a todo with specified status" do
      assert {:ok, todo} = Todos.create_todo("Fix bug", "Fixing bug", "in_progress")
      assert todo.status == "in_progress"
    end

    test "validates status" do
      assert {:error, _} = Todos.create_todo("Fix bug", "Fixing bug", "invalid")
    end

    test "validates required fields" do
      assert {:error, _} = Todos.create_todo("", "Fixing bug")
      assert {:error, _} = Todos.create_todo("Fix bug", "")
    end
  end

  describe "update_todo_status/3" do
    test "updates todo status", %{task_id: task_id} do
      # Add todo via tool result
      {:ok, todo} = Todos.create_todo("Fix bug", "Fixing bug")
      result = Jason.encode!(%{"type" => "todo_add", "todo" => serialize_todo(todo)})
      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, result, false)

      # Get interactions and update
      {:ok, task} = Tasks.get_task(task_id)
      assert {:ok, updated} = Todos.update_todo_status(task.interactions, todo.id, "completed")
      assert updated.status == "completed"
      assert DateTime.compare(updated.updated_at, todo.updated_at) == :gt
    end

    test "validates status", %{task_id: task_id} do
      {:ok, task} = Tasks.get_task(task_id)
      assert {:error, _} = Todos.update_todo_status(task.interactions, "some_id", "invalid")
    end

    test "returns error for non-existent todo", %{task_id: task_id} do
      {:ok, task} = Tasks.get_task(task_id)
      assert {:error, :not_found} =
        Todos.update_todo_status(task.interactions, "nonexistent_id", "completed")
    end
  end

  describe "validate_todo_exists/2" do
    test "validates todo exists", %{task_id: task_id} do
      # Add todo via tool result
      {:ok, todo} = Todos.create_todo("Fix bug", "Fixing bug")
      result = Jason.encode!(%{"type" => "todo_add", "todo" => serialize_todo(todo)})
      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, result, false)

      {:ok, task} = Tasks.get_task(task_id)
      assert :ok = Todos.validate_todo_exists(task.interactions, todo.id)
    end

    test "returns error for non-existent todo", %{task_id: task_id} do
      {:ok, task} = Tasks.get_task(task_id)
      assert {:error, :not_found} = Todos.validate_todo_exists(task.interactions, "nonexistent_id")
    end
  end

  describe "event sourcing" do
    test "rebuilds state from tool result interactions", %{task_id: task_id} do
      # Simulate tool results being stored as interactions
      {:ok, todo1} = Todos.create_todo("Fix bug", "Fixing bug")
      {:ok, todo2} = Todos.create_todo("Write tests", "Writing tests")

      # Add them as tool results (would normally happen via tool execution)
      result1 = Jason.encode!(%{"type" => "todo_add", "todo" => serialize_todo(todo1)})
      result2 = Jason.encode!(%{"type" => "todo_add", "todo" => serialize_todo(todo2)})

      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, result1, false)
      Tasks.add_tool_result(task_id, %{id: "call2", name: "todo_add"}, result2, false)

      # Rebuild should recover both todos
      {:ok, task} = Tasks.get_task(task_id)
      todos = Todos.list_todos(task.interactions)
      assert length(todos) == 2
    end

    test "applies updates correctly", %{task_id: task_id} do
      # Add todo
      {:ok, todo} = Todos.create_todo("Fix bug", "Fixing bug")
      result = Jason.encode!(%{"type" => "todo_add", "todo" => serialize_todo(todo)})
      Tasks.add_tool_result(task_id, %{id: "call1", name: "todo_add"}, result, false)

      # Update todo
      {:ok, task} = Tasks.get_task(task_id)
      {:ok, updated} = Todos.update_todo_status(task.interactions, todo.id, "completed")
      update_result = Jason.encode!(%{"type" => "todo_update", "todo" => serialize_todo(updated)})
      Tasks.add_tool_result(task_id, %{id: "call2", name: "todo_update"}, update_result, false)

      # Rebuild should show updated status
      {:ok, task} = Tasks.get_task(task_id)
      todos = Todos.list_todos(task.interactions)
      assert Enum.find(todos, &(&1.id == todo.id)).status == "completed"
    end

    test "applies removal correctly", %{task_id: task_id} do
      # Add two todos
      {:ok, todo1} = Todos.create_todo("Fix bug", "Fixing bug")
      {:ok, todo2} = Todos.create_todo("Write tests", "Writing tests")

      Tasks.add_tool_result(task_id, %{id: "c1", name: "todo_add"},
        Jason.encode!(%{"type" => "todo_add", "todo" => serialize_todo(todo1)}), false)
      Tasks.add_tool_result(task_id, %{id: "c2", name: "todo_add"},
        Jason.encode!(%{"type" => "todo_add", "todo" => serialize_todo(todo2)}), false)

      # Remove first todo
      remove_result = Jason.encode!(%{"type" => "todo_remove", "todo" => %{"id" => todo1.id}})
      Tasks.add_tool_result(task_id, %{id: "c3", name: "todo_remove"}, remove_result, false)

      # Rebuild should only show second todo
      {:ok, task} = Tasks.get_task(task_id)
      todos = Todos.list_todos(task.interactions)
      assert length(todos) == 1
      assert hd(todos).id == todo2.id
    end
  end

  defp serialize_todo(%Todo{} = todo) do
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
