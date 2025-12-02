defmodule FrontmanServerWeb.ACPTest do
  use ExUnit.Case, async: true

  alias FrontmanServerWeb.ACP
  alias FrontmanServer.Tasks.Todos

  describe "todos_to_plan_entries/1" do
    test "converts empty list to empty list" do
      assert ACP.todos_to_plan_entries([]) == []
    end

    test "converts todos to plan entries with default priority" do
      {:ok, todo} = Todos.create_todo("Test content", "Testing", "pending")

      [entry] = ACP.todos_to_plan_entries([todo])

      assert entry["content"] == "Test content"
      assert entry["priority"] == "medium"
      assert entry["status"] == "pending"
    end

    test "sorts entries by created_at" do
      base_time = DateTime.utc_now()
      earlier = DateTime.add(base_time, -10, :second)
      later = DateTime.add(base_time, 10, :second)

      todo1 = %Todos.Todo{
        id: "id1", content: "First", active_form: "First",
        status: :pending, created_at: earlier, updated_at: earlier
      }
      todo2 = %Todos.Todo{
        id: "id2", content: "Second", active_form: "Second",
        status: :pending, created_at: later, updated_at: later
      }

      # Pass in wrong order
      entries = ACP.todos_to_plan_entries([todo2, todo1])

      assert Enum.map(entries, & &1["content"]) == ["First", "Second"]
    end

    test "handles multiple todos with all statuses" do
      base_time = DateTime.utc_now()
      t1 = DateTime.add(base_time, -20, :second)
      t2 = DateTime.add(base_time, -10, :second)
      t3 = base_time

      todo1 = %Todos.Todo{
        id: "id1", content: "Task 1", active_form: "Working 1",
        status: :pending, created_at: t1, updated_at: t1
      }
      todo2 = %Todos.Todo{
        id: "id2", content: "Task 2", active_form: "Working 2",
        status: :in_progress, created_at: t2, updated_at: t2
      }
      todo3 = %Todos.Todo{
        id: "id3", content: "Task 3", active_form: "Working 3",
        status: :completed, created_at: t3, updated_at: t3
      }

      # Pass in wrong order
      entries = ACP.todos_to_plan_entries([todo3, todo1, todo2])

      assert length(entries) == 3
      assert Enum.map(entries, & &1["content"]) == ["Task 1", "Task 2", "Task 3"]
      assert Enum.map(entries, & &1["status"]) == ["pending", "in_progress", "completed"]
      assert Enum.all?(entries, fn e -> e["priority"] == "medium" end)
    end
  end

  describe "plan_update/2" do
    test "builds valid plan update notification" do
      entries = [
        %{"content" => "Test task", "priority" => "medium", "status" => "pending"}
      ]

      result = ACP.plan_update("sess_123", entries)

      assert result["jsonrpc"] == "2.0"
      assert result["method"] == "session/update"
      assert result["params"]["sessionId"] == "sess_123"
      assert result["params"]["update"]["sessionUpdate"] == "plan"
      assert result["params"]["update"]["entries"] == entries
    end

    test "validates entries have required fields" do
      invalid_entries = [%{"content" => "Missing priority and status"}]

      assert_raise ArgumentError, fn ->
        ACP.plan_update("sess_123", invalid_entries)
      end
    end

    test "validates priority values" do
      invalid_entries = [
        %{"content" => "Test", "priority" => "urgent", "status" => "pending"}
      ]

      assert_raise ArgumentError, fn ->
        ACP.plan_update("sess_123", invalid_entries)
      end
    end

    test "validates status values" do
      invalid_entries = [
        %{"content" => "Test", "priority" => "medium", "status" => "done"}
      ]

      assert_raise ArgumentError, fn ->
        ACP.plan_update("sess_123", invalid_entries)
      end
    end
  end

  describe "todos_to_plan_entries → plan_update invariant" do
    test "output is always valid input for plan_update" do
      {:ok, todo_pending} = Todos.create_todo("Pending", "Working", "pending")
      {:ok, todo_progress} = Todos.create_todo("In progress", "Working", "in_progress")
      {:ok, todo_done} = Todos.create_todo("Done", "Working", "completed")

      entries = ACP.todos_to_plan_entries([todo_pending, todo_progress, todo_done])

      # Should not raise
      notification = ACP.plan_update("sess_test", entries)
      assert notification["params"]["update"]["entries"] == entries
    end

    test "empty todos produces valid empty plan" do
      entries = ACP.todos_to_plan_entries([])
      notification = ACP.plan_update("sess_test", entries)
      assert notification["params"]["update"]["entries"] == []
    end
  end
end
