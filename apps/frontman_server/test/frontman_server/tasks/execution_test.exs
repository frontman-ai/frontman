defmodule FrontmanServer.Tasks.ExecutionIntegrationTest do
  @moduledoc """
  Integration tests for task execution flow.

  Tests the full lifecycle: cancel, tool result routing, consecutive messages.
  These exercise the Tasks facade which delegates to Tasks.Execution.
  """
  use SwarmAi.Testing, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.{Execution, Interaction}

  describe "cancel_execution/2" do
    test "returns error when no agent is running" do
      assert {:error, :not_running} = Tasks.cancel_execution(%Scope{}, "nonexistent_task")
    end

    test "kills a running agent and returns :ok" do
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      task_id = Ecto.UUID.generate()
      test_pid = self()

      # Simulate a running agent by spawning a process and registering it
      # Uses the Runtime's internal registry and key pattern
      runtime_registry = SwarmAi.Runtime.registry_name(FrontmanServer.AgentRuntime)

      agent_pid =
        spawn(fn ->
          Registry.register(runtime_registry, {:running, task_id}, %{})
          # Signal that registration is complete
          send(test_pid, :registered)
          # Keep the process alive until killed
          Process.sleep(:infinity)
        end)

      # Monitor before cancel so we don't miss the :DOWN message
      ref = Process.monitor(agent_pid)

      # Wait for registration to complete
      assert_receive :registered, 1_000

      assert SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id)
      assert :ok = Tasks.cancel_execution(%Scope{}, task_id)

      # The agent process should be dead with :cancelled reason
      assert_receive {:DOWN, ^ref, :process, ^agent_pid, :cancelled}, 1_000
    end
  end

  describe "notify_tool_result" do
    test "returns :ok even when no agent is waiting (backend tool case)" do
      # Backend tools don't have a waiting agent - they execute synchronously
      result = Execution.notify_tool_result(%Scope{}, "call_123", "result", false)
      assert result == :ok
    end
  end

  describe "cancel_execution/2 end-to-end" do
    setup do
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      {:ok, user} =
        Accounts.register_user(%{
          email: "cancel_e2e_#{System.unique_integer([:positive])}@test.local",
          name: "Test User",
          password: "testpassword123!"
        })

      scope = Scope.for_user(user)
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      {:ok, task_id: task_id, scope: scope}
    end

    test "cancel broadcasts :agent_cancelled via PubSub", %{
      task_id: task_id,
      scope: scope
    } do
      # Start a slow agent so we have time to cancel it
      slow_llm = %MockLLM{response: "slow", delay_ms: 5000}
      agent = test_agent(slow_llm, "SlowAgent")

      user_content = [%{"type" => "text", "text" => "Hello"}]
      {:ok, _} = Tasks.add_user_message(scope, task_id, user_content, [], agent: agent)

      # Wait for the agent to start running
      Process.sleep(100)
      assert SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id)

      # Cancel it
      assert :ok = Tasks.cancel_execution(scope, task_id)

      assert_receive :agent_cancelled, 5_000

      # Agent should no longer be running
      refute SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id)
    end
  end

  describe "consecutive messages" do
    setup do
      # Set up database sandbox
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      # Create a test user for scope
      {:ok, user} =
        Accounts.register_user(%{
          email: "agents_test_#{System.unique_integer([:positive])}@test.local",
          name: "Test User",
          password: "testpassword123!"
        })

      scope = Scope.for_user(user)
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      # Subscribe to task topic to receive events
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      {:ok, task_id: task_id, scope: scope}
    end

    test "processes second message after first message completes", %{
      task_id: task_id,
      scope: scope
    } do
      # Create mock agents that respond immediately
      agent1 = test_agent(mock_llm("First response"), "TestAgent1")
      agent2 = test_agent(mock_llm("Second response"), "TestAgent2")

      # Add first user message with custom agent
      user_content = [%{"type" => "text", "text" => "First message"}]
      {:ok, _} = Tasks.add_user_message(scope, task_id, user_content, [], agent: agent1)

      # Wait for first agent to complete
      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      # Verify agent is no longer running
      refute SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id),
             "Agent should not be running after completion"

      # Add second user message with different agent
      user_content2 = [%{"type" => "text", "text" => "Second message"}]
      {:ok, _} = Tasks.add_user_message(scope, task_id, user_content2, [], agent: agent2)

      # Wait for second agent to complete
      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      # Verify both responses are in the task history
      {:ok, task} = Tasks.get_task(scope, task_id)

      agent_responses =
        task.interactions
        |> Enum.filter(&match?(%Interaction.AgentResponse{}, &1))

      assert length(agent_responses) == 2,
             "Expected 2 agent responses, got #{length(agent_responses)}"
    end

    test "second message sent immediately after first completion is processed", %{
      task_id: task_id,
      scope: scope
    } do
      agent1 = test_agent(mock_llm("First response"), "TestAgent1")
      agent2 = test_agent(mock_llm("Second response"), "TestAgent2")

      user_content = [%{"type" => "text", "text" => "First message"}]
      {:ok, _} = Tasks.add_user_message(scope, task_id, user_content, [], agent: agent1)

      # Wait for completion
      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      # Immediately send second message (no delay - maximize race condition chance)
      user_content2 = [%{"type" => "text", "text" => "Second message"}]
      {:ok, _} = Tasks.add_user_message(scope, task_id, user_content2, [], agent: agent2)

      # The second message MUST be processed
      assert_receive {:interaction, %Interaction.AgentCompleted{}},
                     5_000,
                     "Second message was not processed - likely race condition in agent registration"
    end

    test "conversation with tool calls supports follow-up messages", %{
      task_id: task_id,
      scope: scope
    } do
      tool_call = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: "todo_list",
        arguments: "{}"
      }

      agent1 = test_agent(tool_then_complete_llm([tool_call], "Here are your todos"), "Agent1")
      agent2 = test_agent(mock_llm("Based on the previous results..."), "Agent2")

      # First message triggers tool usage
      {:ok, _} =
        Tasks.add_user_message(scope, task_id, [%{"type" => "text", "text" => "Show todos"}], [],
          agent: agent1
        )

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      # Follow-up message should have access to full conversation history
      {:ok, _} =
        Tasks.add_user_message(scope, task_id, [%{"type" => "text", "text" => "Summarize"}], [],
          agent: agent2
        )

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      {:ok, task} = Tasks.get_task(scope, task_id)
      completions = Enum.filter(task.interactions, &match?(%Interaction.AgentCompleted{}, &1))
      assert length(completions) == 2
    end
  end
end
