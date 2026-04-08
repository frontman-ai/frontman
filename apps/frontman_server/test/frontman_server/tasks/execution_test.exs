defmodule FrontmanServer.Tasks.ExecutionIntegrationTest do
  @moduledoc """
  Integration tests for task execution flow.

  Tests the full lifecycle: cancel, tool result routing, consecutive messages,
  and terminal events through the channel layer. These exercise the Tasks
  facade, SwarmDispatcher, and TaskChannel together.
  """
  use SwarmAi.Testing, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  import Phoenix.ChannelTest

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  import FrontmanServer.Test.Fixtures.Tools,
    only: [question_args: 0, question_mcp_tool_defs: 0, todo_args: 0]

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.{ExecutionEvent, Interaction}
  alias FrontmanServer.Tools.MCP
  alias FrontmanServer.Workers.GenerateTitle

  @endpoint FrontmanServerWeb.Endpoint
  @acp_message AgentClientProtocol.event_acp_message()

  # -- Helpers ---------------------------------------------------------------

  # Short timeout for tests that need to observe the pause path quickly.
  defp short_timeout_question_mcp_tool_defs do
    [
      %MCP{
        name: "question",
        description: "Ask the user a question",
        input_schema: %{
          "type" => "object",
          "properties" => %{"questions" => %{"type" => "array"}}
        },
        visible_to_agent: true,
        timeout_ms: 200,
        on_timeout: :pause_agent
      }
    ]
  end

  # Short-timeout tool that fails fast and lets the agent continue.
  defp error_timeout_mcp_tool_defs do
    [
      %MCP{
        name: "question",
        description: "Ask the user a question",
        input_schema: %{
          "type" => "object",
          "properties" => %{"questions" => %{"type" => "array"}}
        },
        visible_to_agent: true,
        timeout_ms: 100,
        on_timeout: :error
      }
    ]
  end

  defp setup_sandbox(_context) do
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    :ok
  end

  defp setup_user(_context) do
    {:ok, scope: user_scope_fixture()}
  end

  defp setup_task(%{scope: scope}) do
    {:ok, task_id: task_with_pubsub_fixture(scope)}
  end

  defp setup_task_only(%{scope: scope}) do
    {:ok, task_id: task_fixture(scope)}
  end

  defp setup_channel(%{scope: scope, task_id: task_id}) do
    {:ok, _reply, socket} =
      FrontmanServerWeb.UserSocket
      |> socket("user_id", %{scope: scope})
      |> subscribe_and_join("task:#{task_id}", %{})

    {:ok, socket: socket}
  end

  # -- Cancel (low-level) ----------------------------------------------------

  describe "cancel_execution/2 (registry-level)" do
    setup [:setup_sandbox]

    test "kills a running agent and returns :ok" do
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
    setup [:setup_sandbox, :setup_user, :setup_task]

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

      assert_receive {:execution_event, %ExecutionEvent{type: :cancelled}}, 5_000
      refute SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id)
    end
  end

  # -- Concurrent execution prevention ----------------------------------------

  describe "concurrent execution prevention" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "second submit returns :already_running while agent is executing", %{
      task_id: task_id,
      scope: scope
    } do
      slow_llm = %MockLLM{response: "slow response", delay_ms: 5_000}
      agent = test_agent(slow_llm, "SlowAgent")

      {:ok, _interaction} =
        Tasks.submit_user_message(scope, task_id, user_content("First"), [], agent: agent)

      Process.sleep(100)
      assert SwarmAi.Runtime.running?(FrontmanServer.AgentRuntime, task_id)

      assert {:error, :already_running} =
               Tasks.submit_user_message(scope, task_id, user_content("Second"), [], agent: agent)

      # Only one completion should fire
      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 6_000
      refute_receive {:interaction, %Interaction.AgentCompleted{}}, 500

      # Only one agent response persisted — second message was rejected entirely
      {:ok, task} = Tasks.get_task(scope, task_id)

      agent_responses =
        Enum.filter(task.interactions, &match?(%Interaction.AgentResponse{}, &1))

      assert length(agent_responses) == 1

      user_messages =
        Enum.filter(task.interactions, &match?(%Interaction.UserMessage{}, &1))

      assert length(user_messages) == 1
    end
  end

  # -- Consecutive messages --------------------------------------------------

  describe "consecutive messages" do
    setup [:setup_sandbox, :setup_user, :setup_task]

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
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "question tool blocks until result arrives, then agent completes", %{
      task_id: task_id,
      scope: scope
    } do
      question_tc_id = "tc_question_#{System.unique_integer([:positive])}"
      question_tc = tool_call("question", question_args(), id: question_tc_id)

      question_swarm_tools = MCP.to_swarm_tools(question_mcp_tool_defs())

      agent =
        test_agent(tool_then_complete_llm([question_tc], "Great choice!"), "QuestionAgent",
          tools: question_swarm_tools
        )

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

      assert_receive {:execution_event, %ExecutionEvent{type: :completed}}, 5_000

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_results =
        Enum.filter(task.interactions, fn
          %Interaction.ToolResult{tool_name: "question"} -> true
          _ -> false
        end)

      assert [_ | _] = tool_results

      completions = Enum.filter(task.interactions, &match?(%Interaction.AgentCompleted{}, &1))
      assert [_ | _] = completions
    end
  end

  # -- Title generation enqueue on first message -----------------------------

  describe "title generation enqueue" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "first message enqueues a title generation job", %{
      task_id: task_id,
      scope: scope
    } do
      agent = test_agent(mock_llm("Response"), "TitleAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Build me a login page"), [],
          agent: agent
        )

      Tasks.enqueue_title_generation(scope, task_id, "Build me a login page")

      assert_enqueued(worker: GenerateTitle, args: %{task_id: task_id})
    end

    test "second message does not enqueue an additional title generation job", %{
      task_id: task_id,
      scope: scope
    } do
      agent1 = test_agent(mock_llm("First response"), "TitleAgent1")
      agent2 = test_agent(mock_llm("Second response"), "TitleAgent2")

      # First message + title enqueue
      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Build me a login page"), [],
          agent: agent1
        )

      {:ok, first_job} =
        Tasks.enqueue_title_generation(scope, task_id, "Build me a login page")

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      # Second message + title enqueue (should be deduplicated by Oban unique constraint)
      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Now add a signup form"), [],
          agent: agent2
        )

      {:ok, second_job} =
        Tasks.enqueue_title_generation(scope, task_id, "Now add a signup form")

      # Oban unique constraint returns the existing job — same ID means no new job was inserted
      assert first_job.id == second_job.id

      # Only one title generation job should exist for this task
      enqueued = all_enqueued(worker: GenerateTitle)

      title_jobs_for_task =
        Enum.filter(enqueued, fn job -> job.args["task_id"] == task_id end)

      assert length(title_jobs_for_task) == 1
    end
  end

  # -- MCP tool timeout — DB invariant (bug 7) ---------------------------------

  describe "interactive tool timeout — ToolResult DB persistence" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "ToolResult is persisted in DB when question tool times out", %{
      task_id: task_id,
      scope: scope
    } do
      question_tc_id = "tc_timeout_#{System.unique_integer([:positive])}"
      question_tc = tool_call("question", question_args(), id: question_tc_id)

      agent =
        test_agent(tool_then_complete_llm([question_tc], "done"), "TimeoutAgent",
          tools: MCP.to_swarm_tools(short_timeout_question_mcp_tool_defs())
        )

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Ask me"), [],
          agent: agent,
          mcp_tool_defs: short_timeout_question_mcp_tool_defs()
        )

      # Wait for the ParallelExecutor deadline to fire and the paused event to broadcast
      assert_receive {:execution_event, %ExecutionEvent{type: :paused}}, 5_000

      {:ok, task} = Tasks.get_task(scope, task_id)

      # Bug 7: the old execute_mcp_tool had an after clause that persisted a
      # ToolResult on timeout. The new code removed it, leaving an orphaned
      # ToolCall — reconnecting clients see the tool as perpetually in-progress.
      #
      # Double-persist guard: EXIT handler and SwarmDispatcher both attempt to
      # persist a ToolResult for on_timeout: :pause_agent. The unique DB index
      # silently rejects the second write, but the wrong (less informative)
      # message wins. Assert exactly one ToolResult so any double-persist is
      # caught, and that the message comes from SwarmDispatcher (includes
      # timeout_ms and policy name).
      tool_results =
        Enum.filter(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: ^question_tc_id} -> true
          _ -> false
        end)

      assert length(tool_results) == 1,
             "Expected exactly 1 ToolResult for the timed-out ToolCall, got #{length(tool_results)} — double-persist bug"

      [tool_result] = tool_results
      assert tool_result.is_error == true

      assert tool_result.result =~ "on_timeout: :pause_agent",
             "Expected ToolResult message to come from SwarmDispatcher (includes policy name), got: #{inspect(tool_result.result)}"
    end
  end

  # -- MCP tool timeout with on_timeout: :error — DB invariant -------------------

  describe "MCP tool timeout with on_timeout: :error" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "ToolResult is persisted in DB when MCP tool times out (on_timeout: :error)", %{
      task_id: task_id,
      scope: scope
    } do
      question_tc_id = "tc_error_timeout_#{System.unique_integer([:positive])}"
      question_tc = tool_call("question", question_args(), id: question_tc_id)

      # on_timeout: :error — the error ToolResult is fed back to the LLM, agent continues
      agent =
        test_agent(
          tool_then_complete_llm([question_tc], "Understood, the tool timed out."),
          "ErrorTimeoutAgent",
          tools: MCP.to_swarm_tools(error_timeout_mcp_tool_defs())
        )

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Ask me"), [],
          agent: agent,
          mcp_tool_defs: error_timeout_mcp_tool_defs()
        )

      # Agent completes (not pauses) — the error result is sent to the LLM which responds
      assert_receive {:execution_event, %ExecutionEvent{type: :completed}}, 5_000

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_call_interaction =
        Enum.find(task.interactions, fn
          %Interaction.ToolCall{tool_call_id: ^question_tc_id} -> true
          _ -> false
        end)

      assert tool_call_interaction != nil,
             "Expected a ToolCall interaction to be persisted"

      # Every persisted ToolCall must have a matching ToolResult.
      # Bug: the old execute_mcp_tool had an after clause that called Tasks.add_tool_result
      # on timeout; the new code removed it. For on_timeout: :error, no ToolResult is
      # ever written, leaving an orphaned ToolCall that shows as perpetually in-progress
      # on reconnect.
      tool_result =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: ^question_tc_id} -> true
          _ -> false
        end)

      assert tool_result != nil,
             "Expected a ToolResult for the timed-out ToolCall — " <>
               "every persisted ToolCall must have a matching ToolResult"

      assert tool_result.is_error == true
    end
  end

  # -- Agent pause — client notification (bug 8) --------------------------------

  describe "interactive tool timeout — client notification" do
    setup [:setup_sandbox, :setup_user, :setup_task_only, :setup_channel]

    test "session/update is pushed to client when agent pauses", %{
      task_id: task_id,
      socket: socket
    } do
      # Simulate the PubSub broadcast SwarmDispatcher emits after persisting AgentPaused.
      # The channel must push a session/update to the client so the pending
      # session/prompt RPC is resolved and the UI resets.
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:execution_event,
         %ExecutionEvent{
           type: :paused,
           payload: {:timeout, "tc_fake", "question", 120_000}
         }}
      )

      # Flush the channel's message queue before asserting pushes
      :sys.get_state(socket.channel_pid)

      # Bug 8: handle_swarm_event for {:paused, _} returned :ok, which maps
      # to {:noreply, socket} — no push, no RPC reply, client hangs forever.
      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "agent_turn_complete"}
        }
      })
    end
  end

  # -- Backend tool execution — regression: parallel executor missing backend tool_defs ------

  describe "backend tool execution — Tasks facade level" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    # Regression: execution.ex passes `tool_defs: mcp_tools` to Runtime.run, where
    # `mcp_tools` only contains the agent's MCP (SwarmAi.Tool.t()) entries.
    # Backend tools (todo_write, web_fetch) are absent from `tool_defs`, so
    # ParallelExecutor.spawn_or_reject immediately returns "Unknown tool: <name>"
    # instead of dispatching to the ToolExecutor closure.
    test "todo_write executes successfully — not rejected as Unknown tool", %{
      task_id: task_id,
      scope: scope
    } do
      ref =
        :telemetry_test.attach_event_handlers(self(), [[:swarm_ai, :tool, :execute, :stop]])

      on_exit(fn -> :telemetry.detach(ref) end)

      tc_id = "tc_todo_#{System.unique_integer([:positive])}"
      todo_tc = tool_call("todo_write", todo_args(), id: tc_id)
      agent = test_agent(tool_then_complete_llm([todo_tc], "Todos written."), "TodoAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Write todos"), [], agent: agent)

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      # The telemetry stop event fires with is_error: false when the backend tool
      # actually executed, or is_error: true / output "Unknown tool: todo_write"
      # when ParallelExecutor rejects it due to the missing tool_defs bug.
      assert_receive {[:swarm_ai, :tool, :execute, :stop], ^ref, _measurements, meta}
      assert meta.tool_name == "todo_write"

      assert meta.is_error == false,
             "todo_write returned an error — " <>
               "backend tool was rejected by ParallelExecutor (missing from tool_defs). " <>
               "Got: #{inspect(meta.output)}"
    end
  end

  # -- Backend tool execution — channel level -----------------------------------

  describe "backend tool execution — channel level" do
    setup [:setup_sandbox, :setup_user, :setup_task_only, :setup_channel]

    test "todo_write executes through the full channel → executor pipeline", %{
      task_id: task_id,
      scope: scope,
      socket: socket
    } do
      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      ref =
        :telemetry_test.attach_event_handlers(self(), [[:swarm_ai, :tool, :execute, :stop]])

      on_exit(fn -> :telemetry.detach(ref) end)

      tc_id = "tc_todo_ch_#{System.unique_integer([:positive])}"
      todo_tc = tool_call("todo_write", todo_args(), id: tc_id)
      agent = test_agent(tool_then_complete_llm([todo_tc], "Todos written."), "TodoAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Write todos"), [], agent: agent)

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      # Channel should push session/update to the client on completion
      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "agent_turn_complete"}
        }
      })

      # Same backend tool regression check as the Tasks facade level test
      assert_receive {[:swarm_ai, :tool, :execute, :stop], ^ref, _measurements, meta}
      assert meta.tool_name == "todo_write"

      assert meta.is_error == false,
             "todo_write returned an error through the channel pipeline — " <>
               "backend tool was rejected by ParallelExecutor (missing from tool_defs). " <>
               "Got: #{inspect(meta.output)}"
    end
  end

  # Inline stubs — define before any describe block that passes them as
  # backend_tool_modules, so the module atom resolves correctly at compile time.

  defmodule CrashTool do
    @moduledoc false
    @behaviour FrontmanServer.Tools.Backend
    def name, do: "crash_tool"
    def description, do: "always crashes"
    def parameter_schema, do: %{"type" => "object", "properties" => %{}}
    def timeout_ms, do: 5_000
    def on_timeout, do: :error
    def execute(_args, _ctx), do: raise("boom")
  end

  defmodule HangTool do
    @moduledoc false
    @behaviour FrontmanServer.Tools.Backend
    def name, do: "hang_tool"
    def description, do: "hangs forever"
    def parameter_schema, do: %{"type" => "object", "properties" => %{}}
    def timeout_ms, do: 100
    def on_timeout, do: :error
    def execute(_args, _ctx), do: Process.sleep(:infinity)
  end

  # -- Backend tool crash — channel contract ------------------------------------

  describe "backend tool crash — channel notification" do
    setup [:setup_sandbox, :setup_user, :setup_task_only, :setup_channel]

    test "session/update agent_turn_complete is pushed when backend tool raises", %{
      task_id: task_id,
      scope: scope,
      socket: socket
    } do
      tc_id = "tc_crash_ch_#{System.unique_integer([:positive])}"
      crash_tc = tool_call("crash_tool", %{}, id: tc_id)
      agent = test_agent(tool_then_complete_llm([crash_tc], "Handled."), "CrashChanAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Do a thing"), [],
          agent: agent,
          backend_tool_modules: [CrashTool]
        )

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      # Channel must push agent_turn_complete so the client is not left hanging.
      # The domain invariant (ToolResult in DB) is verified in the domain test above.
      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "agent_turn_complete"}
        }
      })
    end
  end

  # -- Backend tool timeout — channel contract -----------------------------------

  describe "backend tool timeout (ParallelExecutor) — channel notification" do
    setup [:setup_sandbox, :setup_user, :setup_task_only, :setup_channel]

    test "session/update agent_turn_complete is pushed when ParallelExecutor deadline fires", %{
      task_id: task_id,
      scope: scope,
      socket: socket
    } do
      tc_id = "tc_hang_ch_#{System.unique_integer([:positive])}"
      hang_tc = tool_call("hang_tool", %{}, id: tc_id)

      agent =
        test_agent(tool_then_complete_llm([hang_tc], "Handled."), "HangChanAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Do a thing"), [],
          agent: agent,
          backend_tool_modules: [HangTool]
        )

      assert_receive {:interaction, %Interaction.AgentCompleted{}}, 5_000

      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"sessionUpdate" => "agent_turn_complete"}
        }
      })
    end
  end

  # -- Terminated (end-to-end through channel) -------------------------------

  describe "supervisor-initiated termination (end-to-end)" do
    setup [:setup_sandbox, :setup_user, :setup_task_only, :setup_channel]

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

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      # Agent whose LLM exits with :shutdown — simulates supervisor kill
      agent = test_agent(%MockLLM{response: fn -> exit(:shutdown) end}, "TermAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Hello"), [], agent: agent)

      # Wait for SwarmDispatcher to broadcast the terminated event before checking the channel.
      assert_receive {:execution_event, %ExecutionEvent{type: :terminated}}, 5_000

      # Flush the channel's message queue before asserting pushes.
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

  # -- Crashed agent (end-to-end through channel) --------------------------------

  describe "crashed agent (end-to-end)" do
    setup [:setup_sandbox, :setup_user, :setup_task_only, :setup_channel]

    test "crashed event persists error, fires telemetry, and pushes agent_turn_complete to client",
         %{
           task_id: task_id,
           scope: scope,
           socket: socket
         } do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:frontman, :task, :stop]
        ])

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      # MockLLM that raises — exception escapes execute_llm_call's try/rescue
      # (happens during stream/3, outside the try block) → crashes the Task
      # process → death watcher dispatches {:crashed, ...}
      agent = test_agent(%MockLLM{response: fn -> raise("agent boom") end}, "CrashAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Hello"), [], agent: agent)

      assert_receive {:execution_event, %ExecutionEvent{type: :crashed}}, 5_000

      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "error",
            "category" => "unknown"
          }
        }
      })

      # Verify DB persistence
      {:ok, task} = Tasks.get_task(scope, task_id)

      agent_error =
        Enum.find(task.interactions, &match?(%Interaction.AgentError{}, &1))

      assert agent_error != nil
      assert agent_error.kind == "crashed"
      assert agent_error.error =~ "agent boom"

      # Verify telemetry
      assert_receive {[:frontman, :task, :stop], ^ref, _measurements, telemetry_meta}
      assert telemetry_meta.task_id == task_id
    end
  end

  # -- Failed agent (end-to-end through channel) ---------------------------------

  describe "failed agent (end-to-end)" do
    setup [:setup_sandbox, :setup_user, :setup_task_only, :setup_channel]

    test "failed event persists classified error, fires telemetry, and pushes agent_turn_complete to client",
         %{
           task_id: task_id,
           scope: scope,
           socket: socket
         } do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:frontman, :task, :stop]
        ])

      Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

      # ErrorLLM returns {:error, reason} from stream/3 — caught inside
      # execute_llm_call at line 468 → Loop.handle_error → {:failed, ...}
      agent = test_agent(%ErrorLLM{error: :llm_error}, "FailAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Hello"), [], agent: agent)

      assert_receive {:execution_event, %ExecutionEvent{type: :failed}}, 5_000

      :sys.get_state(socket.channel_pid)

      assert_push(@acp_message, %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "error",
            "category" => "unknown"
          }
        }
      })

      # Verify DB persistence
      {:ok, task} = Tasks.get_task(scope, task_id)

      agent_error =
        Enum.find(task.interactions, &match?(%Interaction.AgentError{}, &1))

      assert agent_error != nil
      assert agent_error.kind == "failed"
      assert agent_error.retryable == false
      assert agent_error.category == "unknown"

      # Verify telemetry
      assert_receive {[:frontman, :task, :stop], ^ref, _measurements, telemetry_meta}
      assert telemetry_meta.task_id == task_id
    end
  end

  # -- Backend tool crash — DB invariant ----------------------------------------

  describe "backend tool crash — ToolResult DB persistence" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "ToolResult is persisted when backend tool raises", %{
      task_id: task_id,
      scope: scope
    } do
      tc_id = "tc_crash_#{System.unique_integer([:positive])}"
      crash_tc = tool_call("crash_tool", %{}, id: tc_id)
      agent = test_agent(tool_then_complete_llm([crash_tc], "Handled the crash."), "CrashAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Do a thing"), [],
          agent: agent,
          backend_tool_modules: [CrashTool]
        )

      assert_receive {:execution_event, %ExecutionEvent{type: :completed}}, 5_000

      {:ok, task} = Tasks.get_task(scope, task_id)

      # Every ToolCall in the LLM response must have a matching ToolResult in DB.
      tool_result =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: ^tc_id} -> true
          _ -> false
        end)

      assert tool_result != nil,
             "Expected a ToolResult for the crashed backend tool — " <>
               "every dispatched ToolCall must have a matching ToolResult in DB"

      assert tool_result.is_error == true
    end
  end

  # -- Backend tool timeout (ParallelExecutor) — DB invariant -------------------

  describe "backend tool timeout (ParallelExecutor) — ToolResult DB persistence" do
    setup [:setup_sandbox, :setup_user, :setup_task]

    test "ToolResult is persisted when ParallelExecutor deadline fires before tool returns", %{
      task_id: task_id,
      scope: scope
    } do
      tc_id = "tc_hang_#{System.unique_integer([:positive])}"
      hang_tc = tool_call("hang_tool", %{}, id: tc_id)

      agent =
        test_agent(
          tool_then_complete_llm([hang_tc], "Handled the timeout."),
          "HangAgent"
        )

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Do a thing"), [],
          agent: agent,
          backend_tool_modules: [HangTool]
        )

      # on_timeout: :error feeds the error back to the LLM, agent completes normally
      assert_receive {:execution_event, %ExecutionEvent{type: :completed}}, 5_000

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_result =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: ^tc_id} -> true
          _ -> false
        end)

      assert tool_result != nil,
             "Expected a ToolResult for the timed-out backend tool — " <>
               "ParallelExecutor fires before await_backend_tool, bypassing persistence"

      assert tool_result.is_error == true
    end
  end
end
