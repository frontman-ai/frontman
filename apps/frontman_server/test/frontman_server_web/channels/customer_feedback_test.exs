defmodule FrontmanServerWeb.CustomerFeedbackTest do
  use FrontmanServerWeb.ChannelCase, async: false
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.Test.Fixtures.Tools, only: [mcp_tool: 2]

  alias FrontmanServer.CustomerFeedback
  alias FrontmanServer.CustomerFeedback.Feedback
  alias FrontmanServer.Protocols.{JsonRpc, MCP}
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServerWeb.UserSocket

  @name "request_customer_feedback"
  @moduletag :capture_log

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

  test "cancellation before an answer prevents late feedback", context do
    Tasks.handle_swarm_event(context.scope, context.task_id, context.turn, {:cancelled, nil})
    result = reply(%{"outcome" => "answered", "score" => 0})

    assert {:ok, ^result} =
             CustomerFeedback.tool_result(
               context.scope,
               context.task_id,
               context.turn,
               context.call,
               result
             )

    assert Repo.one!(Feedback).score == nil
  end

  test "a resolved tool cannot save a late answer while the turn is still active", context do
    {:ok, _, _} =
      Tasks.resolve_tool_request(
        context.scope,
        context.task_id,
        context.call,
        MCP.tool_result_error("Interrupted"),
        turn_number: context.turn
      )

    result = reply(%{"outcome" => "answered", "score" => 0})

    assert {:ok, ^result} =
             CustomerFeedback.tool_result(
               context.scope,
               context.task_id,
               context.turn,
               context.call,
               result
             )

    assert Repo.one!(Feedback).score == nil
  end

  test "an answer committed before cancellation remains saved without resuming the task",
       context do
    {:ok, result} =
      CustomerFeedback.tool_result(
        context.scope,
        context.task_id,
        context.turn,
        context.call,
        reply(%{"outcome" => "answered", "score" => 0})
      )

    Tasks.handle_swarm_event(context.scope, context.task_id, context.turn, {:cancelled, nil})

    assert {:ok, cancelled, _status} =
             Tasks.resolve_tool_request(context.scope, context.task_id, context.call, result,
               turn_number: context.turn
             )

    assert cancelled.is_error
    assert Repo.one!(Feedback).score == 0
    refute SwarmAi.running?(FrontmanServer.AgentRuntime, context.task_id)
  end

  defp reply(output) do
    MCP.tool_result_text("Untrusted browser reply")
    |> Map.put("structuredContent", output)
    |> Map.put("resultType", "complete")
  end
end
