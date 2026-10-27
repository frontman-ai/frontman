defmodule FrontmanServerWeb.TaskChannelCancellationTest do
  use FrontmanServerWeb.ChannelCase, async: false

  import FrontmanServer.InteractionCase.Helpers, only: [tool_call: 2]
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Protocols.JsonRpc
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Test.Fixtures.{LLMProvider, Tools}

  @moduletag :capture_log

  test "session cancellation reaches an already dispatched tool without claiming rollback", %{
    scope: scope
  } do
    {socket, task_id} = join_task_channel(scope)
    complete_mcp_handshake(socket)
    turn_number = start_turn_fixture(scope, task_id)
    call = tool_call("running-write", "write_file")
    {:ok, _} = persist_tool_call_fixture(scope, task_id, turn_number, call)

    assert_push("mcp:message", %{
      "method" => "tools/call",
      "id" => request_id,
      "params" => %{"name" => "write_file"}
    })

    push(
      socket,
      "acp:message",
      JsonRpc.notification("session/cancel", %{"sessionId" => task_id})
    )

    assert_push("mcp:message", %{
      "method" => "notifications/cancelled",
      "params" => %{"requestId" => ^request_id}
    })

    push(
      socket,
      "mcp:message",
      JsonRpc.success_response(request_id, %{
        "resultType" => "input_required",
        "requestState" => "opaque-state"
      })
    )

    :sys.get_state(socket.channel_pid)

    refute Map.has_key?(
             :sys.get_state(socket.channel_pid).assigns.pending_mcp_tool_requests,
             request_id
           )

    assert {:ok, task} = Tasks.get_task_with_history(scope, task_id)

    refute Enum.any?(
             Tasks.interactions(task),
             &match?(%Interaction.ToolResult{tool_call_id: "running-write"}, &1)
           )
  end

  test "a running agent cancels its write attempt and reconciles late evidence without waking a new turn",
       %{scope: scope} do
    FrontmanServer.BillingFixtures.allow_access_for_scope_fixture(scope)
    {socket, task_id} = join_task_channel(scope)
    tool = Tools.mcp_tool("write_file")
    complete_mcp_handshake(socket, tools: [tool])

    assert %{assigns: %{mcp_status: :ready, active_turn: nil}} =
             :sys.get_state(socket.channel_pid)

    call = SwarmAi.Testing.tool_call("write_file", %{}, id: "reused-id")
    LLMProvider.expect_llm_responses([{:tool_calls, [call], ""}])
    ref = push(socket, "acp:message", build_prompt_request())
    assert_reply(ref, :ok, %{"acp:message" => %{"result" => %{}}})
    :sys.get_state(socket.channel_pid)
    assert {:ok, started} = Tasks.get_task_with_history(scope, task_id)
    assert Enum.any?(Tasks.interactions(started), &match?(%Interaction.TurnStarted{}, &1))

    assert_push(
      "mcp:message",
      %{
        "method" => "tools/call",
        "id" => request_id,
        "params" => %{"name" => "write_file"}
      },
      1_000
    )

    assert SwarmAi.running?(FrontmanServer.AgentRuntime, task_id)
    push(socket, "acp:message", JsonRpc.notification("session/cancel", %{"sessionId" => task_id}))

    assert_push("mcp:message", %{
      "method" => "notifications/cancelled",
      "params" => %{"requestId" => ^request_id}
    })

    assert_push("acp:message", %{"params" => %{"update" => %{"state" => "idle"}}}, 1_000)
    :sys.get_state(socket.channel_pid)
    assert {:ok, task} = Tasks.get_task_with_history(scope, task_id)
    refute Enum.any?(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))

    turn = start_turn_fixture(scope, task_id)

    {:ok, _} =
      persist_tool_call_fixture(scope, task_id, turn, tool_call("reused-id", "write_file"))

    assert_push("mcp:message", %{"method" => "tools/call", "id" => newer_request})
    assert newer_request != request_id

    actual = %{
      "resultType" => "complete",
      "content" => [%{"type" => "text", "text" => "actual write committed"}]
    }

    for _ <- 1..2 do
      push(socket, "mcp:message", JsonRpc.success_response(request_id, actual))
      :sys.get_state(socket.channel_pid)
    end

    assert {:ok, task} = Tasks.get_task_with_history(scope, task_id)

    assert [
             %Interaction.ToolResult{
               result: %{"content" => [%{"text" => "actual write committed"}]}
             }
           ] =
             Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))

    assert {:ok, ^turn, [_]} = Tasks.get_active_turn_unresolved_tool_calls(scope, task_id)
    refute SwarmAi.running?(FrontmanServer.AgentRuntime, task_id)

    refute_push("acp:message", %{
      "params" => %{"update" => %{"toolCallId" => "reused-id", "status" => "completed"}}
    })
  end
end
