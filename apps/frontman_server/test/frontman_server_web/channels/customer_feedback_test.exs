defmodule FrontmanServerWeb.CustomerFeedbackTest do
  use FrontmanServerWeb.ChannelCase, async: false
  import FrontmanServer.Test.Fixtures.Accounts, only: [user_scope_fixture: 0]
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.Test.Fixtures.Tools, only: [mcp_tool: 2]
  import FrontmanServer.ExecutionCase, only: [refute_running_eventually: 1]

  alias FrontmanServer.CustomerFeedback
  alias FrontmanServer.CustomerFeedback.Feedback
  alias FrontmanServer.Protocols.{JsonRpc, MCP}
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses
  alias FrontmanServer.Tools
  alias FrontmanServerWeb.UserSocket

  @name "request_customer_feedback"
  @moduletag :capture_log

  describe "feedback replies" do
    setup %{scope: scope} do
      task = task_fixture(scope)
      turn = start_turn_fixture(scope, task.id)
      call = %SwarmAi.ToolCall{id: "feedback", name: @name, arguments: "{}"}
      {:ok, _} = Tasks.request_client_tool(scope, task.id, turn, call, :interactive)
      assert Repo.aggregate(Feedback, :count) == 0

      {:ok, _, socket} =
        UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{task.id}", %{})

      complete_mcp_handshake(socket, tools: [mcp_tool(@name, %{})])
      push(socket, "acp:message", build_acp_request("session/load", 1, %{"sessionId" => task.id}))
      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{
        "id" => request_id,
        "method" => "tools/call",
        "params" => %{"name" => @name}
      })

      assert Repo.aggregate(Feedback, :count) == 1
      refute CustomerFeedback.eligible?(scope)

      {:ok, _} =
        Registry.register(FrontmanServer.ProcessRegistry, {:tool_call, task.id, call.id}, %{
          caller_pid: self()
        })

      {:ok, socket: socket, task_id: task.id, turn: turn, call: call, request_id: request_id}
    end

    for output <- [%{"outcome" => "answered", "score" => 0}, %{"outcome" => "skipped"}] do
      test "channel persists #{output["outcome"]} before returning the tool result", context do
        output = unquote(Macro.escape(output))

        push(
          context.socket,
          "mcp:message",
          JsonRpc.success_response(context.request_id, reply(output))
        )

        assert_receive {:tool_result, "feedback", [%{text: text}], false}, 1_000
        assert Jason.decode!(text) == output
        assert Repo.one!(Feedback).score == output["score"]
      end
    end

    test "a submitted answer racing cancellation stays saved without resuming the task",
         context do
      Tasks.handle_swarm_event(context.scope, context.task_id, context.turn, {:cancelled, nil})
      assert_receive {:tool_result, "feedback", _, true}

      push(
        context.socket,
        "mcp:message",
        JsonRpc.success_response(
          context.request_id,
          reply(%{"outcome" => "answered", "score" => 0})
        )
      )

      :sys.get_state(context.socket.channel_pid)
      assert Repo.one!(Feedback).score == 0
      refute_receive {:tool_result, "feedback", _, _}

      refute SwarmAi.running?(FrontmanServer.AgentRuntime, context.task_id)
    end

    test "a late reply stays bound to its original turn when a call ID is reused", context do
      {:ok, old_request} =
        Tasks.get_tool_request(context.scope, context.task_id, context.turn, context.call)

      Tasks.handle_swarm_event(context.scope, context.task_id, context.turn, {:cancelled, nil})
      assert_receive {:tool_result, "feedback", _, true}
      next_turn = start_turn_fixture(context.scope, context.task_id)

      {:ok, _} =
        Tasks.request_client_tool(
          context.scope,
          context.task_id,
          next_turn,
          context.call,
          :interactive
        )

      :sys.get_state(context.socket.channel_pid)

      assert_push("mcp:message", %{
        "id" => next_request_id,
        "method" => "tools/call",
        "params" => %{"name" => @name}
      })

      {:ok, next_request} =
        Tasks.get_tool_request(context.scope, context.task_id, next_turn, context.call)

      push(
        context.socket,
        "mcp:message",
        JsonRpc.success_response(
          context.request_id,
          reply(%{"outcome" => "answered", "score" => 0})
        )
      )

      :sys.get_state(context.socket.channel_pid)
      assert Repo.get_by!(Feedback, interaction_id: old_request.id).score == 0
      assert Repo.get_by!(Feedback, interaction_id: next_request.id).score == nil
      refute_receive {:tool_result, "feedback", _, _}

      push(
        context.socket,
        "mcp:message",
        JsonRpc.success_response(
          next_request_id,
          reply(%{"outcome" => "answered", "score" => 9})
        )
      )

      assert_receive {:tool_result, "feedback", _, false}
      assert Repo.get_by!(Feedback, interaction_id: next_request.id).score == 9
    end

    test "request lookup enforces scope, task, turn, call ID and tool name", context do
      other_scope = user_scope_fixture()
      other_task = task_fixture(context.scope)

      for {scope, task_id, turn, call} <- [
            {other_scope, context.task_id, context.turn, context.call},
            {context.scope, other_task.id, context.turn, context.call},
            {context.scope, context.task_id, context.turn + 1, context.call},
            {context.scope, context.task_id, context.turn, %{context.call | id: "other"}},
            {context.scope, context.task_id, context.turn, %{context.call | name: "question"}}
          ] do
        assert {:error, :not_found} = Tasks.get_tool_request(scope, task_id, turn, call)
      end
    end

    test "replayed answers return the first stored rating", context do
      {:ok, request} =
        Tasks.get_tool_request(context.scope, context.task_id, context.turn, context.call)

      {:ok, _} = CustomerFeedback.record_answer(context.scope, request.id, %{"score" => 0})

      push(
        context.socket,
        "mcp:message",
        JsonRpc.success_response(
          context.request_id,
          reply(%{"outcome" => "answered", "score" => 10})
        )
      )

      assert_receive {:tool_result, "feedback", [%{text: text}], false}, 1_000
      assert Jason.decode!(text) == %{"outcome" => "answered", "score" => 0}
      assert Repo.one!(Feedback).score == 0
    end

    test "tool-specific reply validation rejects extra fields", context do
      channel_pid = context.socket.channel_pid
      Process.flag(:trap_exit, true)

      push(
        context.socket,
        "mcp:message",
        JsonRpc.success_response(
          context.request_id,
          reply(%{"outcome" => "answered", "score" => 0, "extra" => true})
        )
      )

      assert_receive {:EXIT, ^channel_pid,
                      {{:badmatch, {:error, :invalid_customer_feedback}}, _stacktrace}},
                     1_000

      assert Repo.one!(Feedback).score == nil
      refute_receive {:tool_result, "feedback", _, _}
    end
  end

  for eligible <- [true, false] do
    @tag eligible: eligible
    test "execution eligibility #{eligible} leaves the replay catalog intact",
         %{scope: scope} = context do
      FrontmanServer.BillingFixtures.allow_access_for_scope_fixture(scope)
      {:ok, _} = ReqLLM.model("openrouter:google/gemini-3.1-pro-preview")

      case context.eligible do
        false ->
          previous_task = task_fixture(scope)
          turn = start_turn_fixture(scope, previous_task.id)
          call = %SwarmAi.ToolCall{id: "previous", name: @name, arguments: "{}"}

          {:ok, _} = Tasks.request_client_tool(scope, previous_task.id, turn, call, :interactive)
          {:ok, request} = Tasks.get_tool_request(scope, previous_task.id, turn, call)
          {:ok, _} = CustomerFeedback.record_request(scope, request)

        true ->
          :ok
      end

      parent = self()

      Mox.expect(LLMProviderMock, :stream_text, fn _model, _messages, opts ->
        send(parent, {:execution_tools, Enum.map(opts[:tools], & &1.name)})
        ReqLLMResponses.response("Done")
      end)

      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket, tools: [mcp_tool(@name, %{}), mcp_tool("question", %{})])
      push(socket, "acp:message", build_prompt_request())
      assert_receive {:execution_tools, names}, 1_000
      assert @name in names == context.eligible
      assert "question" in names

      assert_push("acp:message", %{"params" => %{"update" => %{"state" => "idle"}}}, 1_000)

      channel_socket = :sys.get_state(socket.channel_pid)
      assert Enum.any?(channel_socket.assigns.mcp_tools, &(&1.name == @name))
      assert Map.has_key?(Tools.resolve(:all, channel_socket.assigns.mcp_tools), @name)
      refute_running_eventually(task_id)
    end
  end

  defp reply(output) do
    MCP.tool_result_text("Untrusted browser reply")
    |> Map.put("structuredContent", output)
    |> Map.put("resultType", "complete")
  end
end
