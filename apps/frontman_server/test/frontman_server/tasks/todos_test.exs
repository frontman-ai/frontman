defmodule FrontmanServer.Tasks.TodosTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Todos

  setup do
    scope = user_scope_fixture()
    task_id = task_fixture(scope, framework: "test-framework")

    {:ok, task_id: task_id, scope: scope}
  end

  describe "list_todos/1" do
    test "returns empty map when no interactions", %{task_id: task_id, scope: scope} do
      {:ok, task} = Tasks.get_task(scope, task_id)
      assert %{} = Todos.list_todos(task.interactions)
    end

    test "parses todos from a todo_write result", %{task_id: task_id, scope: scope} do
      write_result = %{
        "todos" => [
          %{
            "id" => Ecto.UUID.generate(),
            "content" => "Fix bug",
            "active_form" => "Fixing bug",
            "status" => "pending",
            "priority" => "high",
            "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
            "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
          },
          %{
            "id" => Ecto.UUID.generate(),
            "content" => "Write tests",
            "active_form" => "Writing tests",
            "status" => "in_progress",
            "priority" => "medium",
            "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
            "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
          }
        ]
      }

      Tasks.add_tool_result(scope, task_id, %{id: "c1", name: "todo_write"}, write_result, false)

      {:ok, task} = Tasks.get_task(scope, task_id)
      todos = Todos.list_todos(task.interactions)
      assert map_size(todos) == 2

      todo_list = Map.values(todos)
      assert Enum.any?(todo_list, &(&1.content == "Fix bug" and &1.priority == :high))
      assert Enum.any?(todo_list, &(&1.content == "Write tests" and &1.status == :in_progress))
    end

    test "last todo_write wins", %{task_id: task_id, scope: scope} do
      first_result = %{
        "todos" => [
          %{
            "id" => Ecto.UUID.generate(),
            "content" => "Old task",
            "active_form" => "Working on old task",
            "status" => "pending",
            "priority" => "medium",
            "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
            "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
          }
        ]
      }

      second_result = %{
        "todos" => [
          %{
            "id" => Ecto.UUID.generate(),
            "content" => "New task",
            "active_form" => "Working on new task",
            "status" => "in_progress",
            "priority" => "high",
            "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
            "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
          }
        ]
      }

      Tasks.add_tool_result(scope, task_id, %{id: "c1", name: "todo_write"}, first_result, false)

      Tasks.add_tool_result(
        scope,
        task_id,
        %{id: "c2", name: "todo_write"},
        second_result,
        false
      )

      {:ok, task} = Tasks.get_task(scope, task_id)
      todos = Todos.list_todos(task.interactions)
      assert map_size(todos) == 1

      [todo] = Map.values(todos)
      assert todo.content == "New task"
      assert todo.priority == :high
    end

    test "error todo_write results are ignored", %{task_id: task_id, scope: scope} do
      good_result = %{
        "todos" => [
          %{
            "id" => Ecto.UUID.generate(),
            "content" => "Good task",
            "active_form" => "Working",
            "status" => "pending",
            "priority" => "medium",
            "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
            "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
          }
        ]
      }

      Tasks.add_tool_result(scope, task_id, %{id: "c1", name: "todo_write"}, good_result, false)

      # Error result should be ignored
      Tasks.add_tool_result(
        scope,
        task_id,
        %{id: "c2", name: "todo_write"},
        "Invalid todo at index 0",
        true
      )

      {:ok, task} = Tasks.get_task(scope, task_id)
      todos = Todos.list_todos(task.interactions)
      assert map_size(todos) == 1
      assert [%{content: "Good task"}] = Map.values(todos)
    end

    test "empty todos array returns empty map", %{task_id: task_id, scope: scope} do
      Tasks.add_tool_result(
        scope,
        task_id,
        %{id: "c1", name: "todo_write"},
        %{"todos" => []},
        false
      )

      {:ok, task} = Tasks.get_task(scope, task_id)
      assert %{} = Todos.list_todos(task.interactions)
    end

    test "old todo_add/update/remove interactions are ignored", %{
      task_id: task_id,
      scope: scope
    } do
      # Simulate legacy interactions
      Tasks.add_tool_result(
        scope,
        task_id,
        %{id: "c1", name: "todo_add"},
        %{"id" => "fake", "content" => "Old todo"},
        false
      )

      Tasks.add_tool_result(
        scope,
        task_id,
        %{id: "c2", name: "todo_update"},
        %{"id" => "fake", "status" => "completed"},
        false
      )

      {:ok, task} = Tasks.get_task(scope, task_id)
      todos = Todos.list_todos(task.interactions)
      assert todos == %{}
    end
  end

  describe "Todo.make/4" do
    test "creates a todo with default priority" do
      assert {:ok, todo} = Todos.Todo.make("Fix bug", "Fixing bug", "pending")
      assert todo.content == "Fix bug"
      assert todo.active_form == "Fixing bug"
      assert todo.status == :pending
      assert todo.priority == :medium
      assert %DateTime{} = todo.created_at
      assert is_binary(todo.id)
    end

    test "creates a todo with specified priority" do
      assert {:ok, todo} = Todos.Todo.make("Fix bug", "Fixing bug", "in_progress", "high")
      assert todo.status == :in_progress
      assert todo.priority == :high
    end

    test "validates status" do
      assert {:error, _} = Todos.Todo.make("Fix bug", "Fixing bug", "invalid")
    end

    test "validates priority" do
      assert {:error, _} = Todos.Todo.make("Fix bug", "Fixing bug", "pending", "critical")
    end

    test "validates required fields" do
      assert {:error, _} = Todos.Todo.make("", "Fixing bug", "pending")
      assert {:error, _} = Todos.Todo.make("Fix bug", "", "pending")
    end
  end
end
