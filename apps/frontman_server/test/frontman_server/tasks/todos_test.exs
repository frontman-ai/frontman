defmodule FrontmanServer.Tasks.TodosTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Todos
  alias ModelContextProtocol, as: MCP

  setup do
    scope = user_scope_fixture()
    task_id = task_with_active_turn_fixture(scope, framework: "nextjs").id

    {:ok, task_id: task_id, scope: scope, turn_number: latest_turn_number(task_id)}
  end

  describe "list_todos/1" do
    test "returns empty map when no interactions", %{task_id: task_id, scope: scope} do
      {:ok, task} = Tasks.get_task(scope, task_id)
      assert %{} = Todos.list_todos(task.interaction_rows)
    end

    test "parses todos from a todo_write result", %{
      task_id: task_id,
      scope: scope,
      turn_number: turn_number
    } do
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

      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: "c1", name: "todo_write"},
        %{"resultType" => "complete", "content" => [], "structuredContent" => write_result},
        turn_number: turn_number
      )

      {:ok, task} = Tasks.get_task(scope, task_id)
      todos = Todos.list_todos(task.interaction_rows)
      assert map_size(todos) == 2

      todo_list = Map.values(todos)
      assert Enum.any?(todo_list, &(&1.content == "Fix bug" and &1.priority == :high))
      assert Enum.any?(todo_list, &(&1.content == "Write tests" and &1.status == :in_progress))
    end

    test "last todo_write wins", %{task_id: task_id, scope: scope, turn_number: turn_number} do
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

      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: "c1", name: "todo_write"},
        %{"resultType" => "complete", "content" => [], "structuredContent" => first_result},
        turn_number: turn_number
      )

      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: "c2", name: "todo_write"},
        %{"resultType" => "complete", "content" => [], "structuredContent" => second_result},
        turn_number: turn_number
      )

      {:ok, task} = Tasks.get_task(scope, task_id)
      todos = Todos.list_todos(task.interaction_rows)
      assert map_size(todos) == 1

      [todo] = Map.values(todos)
      assert todo.content == "New task"
      assert todo.priority == :high
    end

    test "error todo_write results are ignored", %{
      task_id: task_id,
      scope: scope,
      turn_number: turn_number
    } do
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

      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: "c1", name: "todo_write"},
        %{"resultType" => "complete", "content" => [], "structuredContent" => good_result},
        turn_number: turn_number
      )

      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: "c2", name: "todo_write"},
        MCP.tool_result_error("Invalid todo at index 0"),
        turn_number: turn_number
      )

      {:ok, task} = Tasks.get_task(scope, task_id)
      todos = Todos.list_todos(task.interaction_rows)
      assert map_size(todos) == 1
      assert [%{content: "Good task"}] = Map.values(todos)
    end

    test "empty todos array returns empty map", %{
      task_id: task_id,
      scope: scope,
      turn_number: turn_number
    } do
      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: "c1", name: "todo_write"},
        %{
          "resultType" => "complete",
          "content" => [],
          "structuredContent" => %{"todos" => []}
        },
        turn_number: turn_number
      )

      {:ok, task} = Tasks.get_task(scope, task_id)
      assert %{} = Todos.list_todos(task.interaction_rows)
    end

    test "old todo_add/update/remove interactions are ignored", %{
      task_id: task_id,
      scope: scope,
      turn_number: turn_number
    } do
      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: "c1", name: "todo_add"},
        MCP.tool_result_json(%{"id" => "fake", "content" => "Old todo"}),
        turn_number: turn_number
      )

      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: "c2", name: "todo_update"},
        MCP.tool_result_json(%{"id" => "fake", "status" => "completed"}),
        turn_number: turn_number
      )

      {:ok, task} = Tasks.get_task(scope, task_id)
      todos = Todos.list_todos(task.interaction_rows)
      assert todos == %{}
    end
  end

  describe "Tasks.list_todos/1" do
    test "projects todos from an already-loaded task", %{
      task_id: task_id,
      scope: scope,
      turn_number: turn_number
    } do
      todo = %{
        "id" => Ecto.UUID.generate(),
        "content" => "Reuse loaded history",
        "active_form" => "Reusing loaded history",
        "status" => "pending",
        "priority" => "high",
        "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
        "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
      }

      Tasks.resolve_tool_request(
        scope,
        task_id,
        %{id: "loaded-task", name: "todo_write"},
        %{"content" => [], "structuredContent" => %{"todos" => [todo]}},
        turn_number: turn_number
      )

      {:ok, task} = Tasks.get_task(scope, task_id)

      assert [%{content: "Reuse loaded history", priority: :high}] = Tasks.list_todos(task)
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
