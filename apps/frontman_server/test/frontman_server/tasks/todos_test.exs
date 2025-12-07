defmodule FrontmanServer.Tasks.TodosTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Todos
  alias FrontmanServer.Tasks.Todos.Tools.{TodoAdded, TodoUpdated, TodoRemoved}

  setup do
    # Create a task for testing
    task_id = "test_task_#{:rand.uniform(1_000_000)}"
    agent_id = "agent_#{:rand.uniform(1_000_000)}"
    {:ok, ^task_id} = Tasks.create_task(task_id)

    {:ok, task_id: task_id, agent_id: agent_id}
  end

  describe "list_todos/1" do
    test "returns empty map for empty interactions", %{task_id: task_id} do
      {:ok, task} = Tasks.get_task(task_id)
      assert %{} = Todos.list_todos(task.interactions)
    end
  end

  describe "create_todo/3" do
    test "creates a todo with default status" do
      assert {:ok, todo} = Todos.create_todo("Fix bug", "Fixing bug")
      assert todo.content == "Fix bug"
      assert todo.active_form == "Fixing bug"
      assert todo.status == :pending
      assert %DateTime{} = todo.created_at
      assert %DateTime{} = todo.updated_at
      assert is_binary(todo.id)
    end

    test "creates a todo with specified status" do
      assert {:ok, todo} = Todos.create_todo("Fix bug", "Fixing bug", "in_progress")
      assert todo.status == :in_progress
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
    test "updates todo status", %{task_id: task_id, agent_id: agent_id} do
      # Add todo via tool result
      {:ok, todo} = Todos.create_todo("Fix bug", "Fixing bug")
      event = TodoAdded.from_todo(todo)
      Tasks.add_tool_result(task_id, agent_id, %{id: "call1", name: "todo_add"}, event, false)

      # Get interactions and update
      {:ok, task} = Tasks.get_task(task_id)
      assert {:ok, updated} = Todos.update_todo_status(task.interactions, todo.id, "completed")
      assert updated.status == :completed
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
    test "validates todo exists", %{task_id: task_id, agent_id: agent_id} do
      # Add todo via tool result
      {:ok, todo} = Todos.create_todo("Fix bug", "Fixing bug")
      event = TodoAdded.from_todo(todo)
      Tasks.add_tool_result(task_id, agent_id, %{id: "call1", name: "todo_add"}, event, false)

      {:ok, task} = Tasks.get_task(task_id)
      assert :ok = Todos.validate_todo_exists(task.interactions, todo.id)
    end

    test "returns error for non-existent todo", %{task_id: task_id} do
      {:ok, task} = Tasks.get_task(task_id)

      assert {:error, :not_found} =
               Todos.validate_todo_exists(task.interactions, "nonexistent_id")
    end
  end

  describe "event sourcing" do
    test "rebuilds state from tool result interactions", %{task_id: task_id, agent_id: agent_id} do
      {:ok, todo1} = Todos.create_todo("Fix bug", "Fixing bug")
      {:ok, todo2} = Todos.create_todo("Write tests", "Writing tests")

      event1 = TodoAdded.from_todo(todo1)
      event2 = TodoAdded.from_todo(todo2)

      Tasks.add_tool_result(task_id, agent_id, %{id: "call1", name: "todo_add"}, event1, false)
      Tasks.add_tool_result(task_id, agent_id, %{id: "call2", name: "todo_add"}, event2, false)

      {:ok, task} = Tasks.get_task(task_id)
      todos = Todos.list_todos(task.interactions)
      assert map_size(todos) == 2
    end

    test "applies updates correctly", %{task_id: task_id, agent_id: agent_id} do
      {:ok, todo} = Todos.create_todo("Fix bug", "Fixing bug")
      event = TodoAdded.from_todo(todo)
      Tasks.add_tool_result(task_id, agent_id, %{id: "call1", name: "todo_add"}, event, false)

      {:ok, task} = Tasks.get_task(task_id)
      {:ok, updated} = Todos.update_todo_status(task.interactions, todo.id, "completed")

      update_event = %TodoUpdated{
        todo_id: updated.id,
        status: updated.status,
        updated_at: updated.updated_at,
        timestamp: DateTime.utc_now()
      }

      Tasks.add_tool_result(task_id, agent_id, %{id: "call2", name: "todo_update"}, update_event, false)

      {:ok, task} = Tasks.get_task(task_id)
      todos = Todos.list_todos(task.interactions)
      assert Map.get(todos, todo.id).status == :completed
    end

    test "applies removal correctly", %{task_id: task_id, agent_id: agent_id} do
      {:ok, todo1} = Todos.create_todo("Fix bug", "Fixing bug")
      {:ok, todo2} = Todos.create_todo("Write tests", "Writing tests")

      event1 = TodoAdded.from_todo(todo1)
      event2 = TodoAdded.from_todo(todo2)

      Tasks.add_tool_result(task_id, agent_id, %{id: "c1", name: "todo_add"}, event1, false)
      Tasks.add_tool_result(task_id, agent_id, %{id: "c2", name: "todo_add"}, event2, false)

      remove_event = %TodoRemoved{
        todo_id: todo1.id,
        timestamp: DateTime.utc_now()
      }

      Tasks.add_tool_result(task_id, agent_id, %{id: "c3", name: "todo_remove"}, remove_event, false)

      {:ok, task} = Tasks.get_task(task_id)
      todos = Todos.list_todos(task.interactions)
      assert map_size(todos) == 1
      assert Map.get(todos, todo2.id).id == todo2.id
    end
  end
end
