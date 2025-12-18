defmodule FrontmanServer.TasksTest do
  use ExUnit.Case, async: false

  alias FrontmanServer.Tasks

  describe "topic/1" do
    test "returns topic string for task_id" do
      assert Tasks.topic("abc123") == "task:abc123"
    end
  end

  describe "subscribe/2" do
    test "subscribes calling process to task topic" do
      task_id = "test_sub_#{System.unique_integer([:positive])}"

      :ok = Tasks.subscribe(FrontmanServer.PubSub, task_id)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:test_event, "hello"}
      )

      assert_receive {:test_event, "hello"}, 100
    end
  end

  describe "get_interactions/1" do
    test "returns empty list for non-existent task" do
      assert Tasks.get_interactions("nonexistent") == []
    end

    test "returns interactions for existing task" do
      task_id = "test_interactions_#{System.unique_integer([:positive])}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      assert Tasks.get_interactions(task_id) == []
    end
  end

  describe "get_llm_messages/2" do
    test "filters messages by agent_id" do
      task_id = "test_llm_filter_#{System.unique_integer([:positive])}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      # Add a user message
      Tasks.add_user_message(task_id, [%{"type" => "text", "text" => "Hello"}])

      # Add responses from two different agents
      Tasks.add_agent_response(task_id, "agent_a", "Response from A", %{})
      Tasks.add_agent_response(task_id, "agent_b", "Response from B", %{})
      Tasks.add_agent_response(task_id, "agent_a", "Another from A", %{})

      # Filter for agent_a
      messages = Tasks.get_llm_messages(task_id, "agent_a")

      # Should have: UserMessage + 2 responses from agent_a = 3 messages
      assert length(messages) == 3

      # All assistant messages should be from agent_a
      assistant_messages = Enum.filter(messages, &(&1.role == :assistant))
      assert length(assistant_messages) == 2
    end
  end

  describe "add_tool_call/3" do
    test "creates tool call interaction" do
      task_id = "test_tool_call_#{System.unique_integer([:positive])}"
      {:ok, ^task_id} = Tasks.create_task(task_id)
      agent_id = Ecto.UUID.generate()

      tool_call = ReqLLM.ToolCall.new("call_123", "calculator", ~s({"expression": "1 + 1"}))

      {:ok, interaction} = Tasks.add_tool_call(task_id, agent_id, tool_call)

      assert interaction.tool_name == "calculator"
      assert interaction.tool_call_id == "call_123"
      assert interaction.arguments == %{"expression" => "1 + 1"}
    end

    test "returns error for non-existent task" do
      tool_call = ReqLLM.ToolCall.new("call_123", "test", "{}")

      assert {:error, :task_not_found} =
               Tasks.add_tool_call("nonexistent", "agent", tool_call)
    end
  end

  describe "add_tool_result/5" do
    test "creates tool result interaction" do
      task_id = "test_tool_result_#{System.unique_integer([:positive])}"
      {:ok, ^task_id} = Tasks.create_task(task_id)
      agent_id = "agent_#{System.unique_integer([:positive])}"

      tool_call_data = %{id: "call_123", name: "calculator"}

      # Register the tool call in Registry (simulating what agent does)
      Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call_data.id}, agent_id)

      {:ok, interaction} = Tasks.add_tool_result(task_id, agent_id, tool_call_data, 2, false)

      assert interaction.result == 2
      assert interaction.is_error == false
      assert interaction.tool_call_id == "call_123"
      assert interaction.agent_id == agent_id
    end

    test "creates error tool result" do
      task_id = "test_tool_error_#{System.unique_integer([:positive])}"
      {:ok, ^task_id} = Tasks.create_task(task_id)
      agent_id = "agent_#{System.unique_integer([:positive])}"

      tool_call_data = %{id: "call_456", name: "failing_tool"}

      # Register the tool call in Registry
      Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call_data.id}, agent_id)

      {:ok, interaction} =
        Tasks.add_tool_result(task_id, agent_id, tool_call_data, "error message", true)

      assert interaction.is_error == true
      assert interaction.result == "error message"
      assert interaction.agent_id == agent_id
    end

    test "notifies agent via Registry" do
      task_id = "test_tool_notify_#{System.unique_integer([:positive])}"
      {:ok, ^task_id} = Tasks.create_task(task_id)
      agent_id = "agent_#{System.unique_integer([:positive])}"

      tool_call_data = %{id: "call_notify", name: "some_tool"}

      # Register the tool call in Registry
      Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call_data.id}, agent_id)

      {:ok, _interaction} =
        Tasks.add_tool_result(task_id, agent_id, tool_call_data, "result", false)

      # The tool result should have been stored successfully
      interactions = Tasks.get_interactions(task_id)
      assert length(interactions) == 1
    end
  end

  describe "list_todos/1" do
    test "returns empty list for task with no todos" do
      task_id = "test_list_todos_#{System.unique_integer([:positive])}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      assert {:ok, []} = Tasks.list_todos(task_id)
    end

    test "returns error for non-existent task" do
      assert {:error, :not_found} = Tasks.list_todos("nonexistent")
    end

    test "returns todos from task" do
      task_id = "test_list_todos_#{System.unique_integer([:positive])}"
      {:ok, ^task_id} = Tasks.create_task(task_id)
      agent_id = "agent_#{System.unique_integer([:positive])}"

      {:ok, todo1} = Tasks.create_todo("First", "First", "pending")
      Tasks.add_tool_result(task_id, agent_id, %{id: "c1", name: "todo_add"}, todo1, false)

      {:ok, todo2} = Tasks.create_todo("Second", "Second", "in_progress")
      Tasks.add_tool_result(task_id, agent_id, %{id: "c2", name: "todo_add"}, todo2, false)

      {:ok, todos} = Tasks.list_todos(task_id)

      assert length(todos) == 2
      contents = Enum.map(todos, & &1.content)
      assert "First" in contents
      assert "Second" in contents
    end

    test "todos are isolated per task" do
      task_a = "test_isolation_a_#{System.unique_integer([:positive])}"
      task_b = "test_isolation_b_#{System.unique_integer([:positive])}"
      {:ok, ^task_a} = Tasks.create_task(task_a)
      {:ok, ^task_b} = Tasks.create_task(task_b)
      agent_id = "agent_#{System.unique_integer([:positive])}"

      {:ok, todo} = Tasks.create_todo("Task A todo", "Working", "pending")
      Tasks.add_tool_result(task_a, agent_id, %{id: "c1", name: "todo_add"}, todo, false)

      {:ok, todos_a} = Tasks.list_todos(task_a)
      {:ok, todos_b} = Tasks.list_todos(task_b)

      assert length(todos_a) == 1
      assert length(todos_b) == 0
    end
  end
end
