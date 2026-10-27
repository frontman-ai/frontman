defmodule FrontmanServerWeb.TaskChannelCancellationTest do
  use FrontmanServerWeb.ChannelCase, async: false

  import FrontmanServer.InteractionCase.Helpers, only: [tool_call: 2]
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Protocols.JsonRpc
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction

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

    :sys.get_state(socket.channel_pid)
    assert {:ok, task} = Tasks.get_task_with_history(scope, task_id)

    refute Enum.any?(
             Tasks.interactions(task),
             &match?(%Interaction.ToolResult{tool_call_id: "running-write"}, &1)
           )
  end
end
