defmodule FrontmanServer.Tasks.ExecutionIntegrationTest do
  @moduledoc """
  Integration tests for task execution flow.

  Tests the full lifecycle: cancel, tool result routing, consecutive messages,
  and terminal events through the channel layer. These exercise the Tasks
  facade, SwarmDispatcher, and TaskChannel together.
  """
  use SwarmAi.Testing, async: false

  import Phoenix.ChannelTest

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction

  @endpoint FrontmanServerWeb.Endpoint
  @acp_message AgentClientProtocol.event_acp_message()

  # -- Helpers ---------------------------------------------------------------

  defp user_content(text), do: [%{"type" => "text", "text" => text}]

  defp question_args do
    %{
      "questions" => [
        %{
          "question" => "Pick one",
          "header" => "Test",
          "options" => [%{"label" => "A", "description" => "Option A"}]
        }
      ]
    }
  end

  alias FrontmanServer.Tools.MCP

  defp question_mcp_tool_defs do
    [
      %MCP{
        name: "question",
        description: "Ask the user a question",
        input_schema: %{
          "type" => "object",
          "properties" => %{"questions" => %{"type" => "array"}}
        },
        visible_to_agent: true,
        execution_mode: :interactive
      }
    ]
  end

  defp setup_task(_context) do
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "exec_test_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    task_id = Ecto.UUID.generate()
    {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

    {:ok, task_id: task_id, scope: scope}
  end

  defp setup_task_with_channel(_context) do
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "exec_ch_test_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    task_id = Ecto.UUID.generate()
    {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

    {:ok, _reply, socket} =
      FrontmanServerWeb.UserSocket
      |> socket("user_id", %{scope: scope})
      |> subscribe_and_join("task:#{task_id}", %{})

    {:ok, task_id: task_id, scope: scope, socket: socket}
  end

  # -- Cancel (low-level) ----------------------------------------------------

  describe "cancel_execution/2 (registry-level)" do
    test "kills a running agent and returns :ok" do
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      task_id = Ecto.UUID.generate()
      test_pid = self()

      runtime_registry = SwarmAi.Runtime.registry_name(FrontmanServer.AgentRuntime)

      agent_pid =
        spawn(fn ->
          Registry.register(runtime_registry, {:running, task_id}, %{})
          send(test_pid, :registered)
          Process.sleep(:infinity)
        end)

      ref = Process.monitor(agent_pid)
      assert_receive :registered, 1_000

      assert SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id)
      assert :ok = Tasks.cancel_execution(%Scope{}, task_id)

      assert_receive {:DOWN, ^ref, :process, ^agent_pid, :cancelled}, 1_000
    end
  end

  # -- Cancel (end-to-end) ---------------------------------------------------

  describe "cancel_execution/2 (end-to-end)" do
    setup :setup_task

    test "cancel dispatches cancelled event via PubSub", %{
      task_id: task_id,
      scope: scope
    } do
      slow_llm = %MockLLM{response: "slow", delay_ms: 5000}
      agent = test_agent(slow_llm, "SlowAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Hello"), [], agent: agent)

      Process.sleep(100)
      assert SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id)

      assert :ok = Tasks.cancel_execution(scope, task_id)

      assert_receive {:swarm_event, {:cancelled, _}}, 5_000
      refute SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id)
    end
  end

  # -- Consecutive messages --------------------------------------------------

  describe "consecutive messages" do
    setup :setup_task

    test "processes second message after first message completes", %{
      task_id: task_id,
      scope: scope
    } do
      agent1 = test_agent(mock_llm("First response"), "TestAgent1")
      agent2 = test_agent(mock_llm("Second response"), "TestAgent2")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("First message"), [],
          agent: agent1
        )

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      refute SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id),
             "Agent should not be running after completion"

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Second message"), [],
          agent: agent2
        )

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      {:ok, task} = Tasks.get_task(scope, task_id)

      agent_responses =
        Enum.filter(task.interactions, &match?(%Interaction.AgentResponse{}, &1))

      assert length(agent_responses) == 2,
             "Expected 2 agent responses, got #{length(agent_responses)}"
    end

    test "conversation with tool calls supports follow-up messages", %{
      task_id: task_id,
      scope: scope
    } do
      tc = tool_call("todo_write")
      agent1 = test_agent(tool_then_complete_llm([tc], "Here are your todos"), "Agent1")
      agent2 = test_agent(mock_llm("Based on the previous results..."), "Agent2")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Show todos"), [], agent: agent1)

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Summarize"), [], agent: agent2)

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      {:ok, task} = Tasks.get_task(scope, task_id)
      completions = Enum.filter(task.interactions, &match?(%Interaction.AgentCompleted{}, &1))
      assert length(completions) == 2
    end
  end

  # -- Interactive tool (question) with blocking receive ----------------------

  describe "interactive tool (question) blocking" do
    setup :setup_task

    test "question tool blocks until result arrives, then agent completes", %{
      task_id: task_id,
      scope: scope
    } do
      question_tc_id = "tc_question_#{System.unique_integer([:positive])}"
      question_tc = tool_call("question", question_args(), id: question_tc_id)

      agent = test_agent(tool_then_complete_llm([question_tc], "Great choice!"), "QuestionAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Ask me"), [],
          agent: agent,
          mcp_tool_defs: question_mcp_tool_defs()
        )

      # Agent should still be running (blocking on receive)
      Process.sleep(200)
      assert SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id)

      # Submit the tool result — this unblocks the agent
      answer = Jason.encode!(%{"answers" => [%{"answer" => "A"}]})

      {:ok, _interaction, _status} =
        Tasks.add_tool_result(
          scope,
          task_id,
          %{id: question_tc_id, name: "question"},
          answer,
          false
        )

      assert_receive {:swarm_event, {:completed, _}}, 5_000

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_results =
        Enum.filter(task.interactions, fn
          %Interaction.ToolResult{tool_name: "question"} -> true
          _ -> false
        end)

      assert tool_results != []

      completions = Enum.filter(task.interactions, &match?(%Interaction.AgentCompleted{}, &1))
      assert completions != []
    end
  end

  # -- Terminated (end-to-end through channel) -------------------------------

  describe "supervisor-initiated termination (end-to-end)" do
    setup :setup_task_with_channel

    test "terminated event persists error, fires telemetry, and pushes cancelled to client", %{
      task_id: task_id,
      scope: scope,
      socket: socket
    } do
      # Attach telemetry handler before triggering the event
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:frontman, :task, :stop]
        ])

      # Agent whose LLM exits with :shutdown — simulates supervisor kill
      agent = test_agent(%MockLLM{response: fn -> exit(:shutdown) end}, "TermAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Hello"), [], agent: agent)

      # Wait for the runtime to exit and SwarmDispatcher to broadcast
      Process.sleep(500)

      # Channel should receive the event via PubSub and push cancelled to client
      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "agent_turn_complete",
            "stopReason" => "cancelled"
          }
        }
      })

      # Verify DB persistence
      {:ok, task} = Tasks.get_task(scope, task_id)

      agent_error =
        Enum.find(task.interactions, &match?(%Interaction.AgentError{}, &1))

      assert agent_error != nil
      assert agent_error.kind == "terminated"
      assert agent_error.error == "Terminated by supervisor"

      # Verify telemetry
      assert_receive {[:frontman, :task, :stop], ^ref, _measurements, telemetry_meta}
      assert telemetry_meta.task_id == task_id
    end
  end
end
