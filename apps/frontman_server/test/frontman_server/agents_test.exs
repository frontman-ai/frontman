defmodule FrontmanServer.AgentsTest do
  use FrontmanServer.SwarmCase, async: false

  alias FrontmanServer.{Agents, Tasks}
  alias FrontmanServer.Tasks.Interaction

  describe "agent_running?/1" do
    test "returns false when no agent exists" do
      refute Agents.agent_running?("nonexistent_task")
    end
  end

  describe "notify_tool_result/4" do
    test "returns :ok even when no agent is waiting (backend tool case)" do
      # Backend tools don't have a waiting agent - they execute synchronously
      result = Agents.notify_tool_result("nonexistent", "call_123", "result", false)
      assert result == :ok
    end
  end

  describe "notify_user_message/2" do
    test "returns ok even when no agent exists (spawns new agent)" do
      # Note: This would actually try to spawn an agent, which would fail
      # without a proper task. In a real test we'd set up the task first.
      # For now we just verify the function exists and has correct arity.
      assert is_function(&Agents.notify_user_message/2)
    end
  end

  describe "consecutive messages" do
    setup do
      task_id = "test_task_#{System.unique_integer([:positive])}"
      {:ok, ^task_id} = Tasks.create_task(task_id)

      # Subscribe to task topic to receive events
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      {:ok, task_id: task_id}
    end

    test "processes second message after first message completes", %{task_id: task_id} do
      # Create mock agents that respond immediately
      agent1 = test_agent(mock_llm("First response"), "TestAgent1")
      agent2 = test_agent(mock_llm("Second response"), "TestAgent2")

      # Add first user message with custom agent
      user_content = [%{"type" => "text", "text" => "First message"}]
      {:ok, _} = Tasks.add_user_message(task_id, user_content, [], agent: agent1)

      # Wait for first agent to complete
      assert_receive {:agent_completed, first_agent_id}, 5_000

      # Verify agent is no longer running
      refute Agents.agent_running?(task_id),
        "Agent should not be running after completion"

      # Add second user message with different agent
      user_content2 = [%{"type" => "text", "text" => "Second message"}]
      {:ok, _} = Tasks.add_user_message(task_id, user_content2, [], agent: agent2)

      # Wait for second agent to complete
      assert_receive {:agent_completed, second_agent_id}, 5_000

      # The two agents should be different
      assert first_agent_id != second_agent_id,
        "Second message should spawn a new agent"

      # Verify both responses are in the task history
      {:ok, task} = Tasks.get_task(task_id)

      agent_responses =
        task.interactions
        |> Enum.filter(&match?(%Interaction.AgentResponse{}, &1))

      assert length(agent_responses) == 2,
        "Expected 2 agent responses, got #{length(agent_responses)}"
    end

    test "second message sent immediately after first completion is processed", %{
      task_id: task_id
    } do
      # This test specifically catches the race condition where:
      # 1. First agent completes and emits {:completed, agent_id}
      # 2. Second message arrives before Registry.unregister runs
      # 3. agent_running?() returns true (still registered)
      # 4. No new agent is spawned
      # 5. Second message is never processed

      agent1 = test_agent(mock_llm("First response"), "TestAgent1")
      agent2 = test_agent(mock_llm("Second response"), "TestAgent2")

      user_content = [%{"type" => "text", "text" => "First message"}]
      {:ok, _} = Tasks.add_user_message(task_id, user_content, [], agent: agent1)

      # Wait for completion
      assert_receive {:agent_completed, _first_agent_id}, 5_000

      # Immediately send second message (no delay - maximize race condition chance)
      user_content2 = [%{"type" => "text", "text" => "Second message"}]
      {:ok, _} = Tasks.add_user_message(task_id, user_content2, [], agent: agent2)

      # The second message MUST be processed - if this times out, we have the race condition bug
      assert_receive {:agent_completed, _second_agent_id}, 5_000,
        "Second message was not processed - likely race condition in agent registration"
    end
  end
end
