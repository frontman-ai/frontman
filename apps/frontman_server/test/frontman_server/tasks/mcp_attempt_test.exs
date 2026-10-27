defmodule FrontmanServer.Tasks.MCPAttemptTest do
  use FrontmanServer.DataCase, async: false
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  alias FrontmanServer.Tasks

  test "cancellation is durable, attempt-fenced, and does not fabricate a result" do
    scope = user_scope_fixture()
    id = task_fixture(scope).id
    turn = start_turn_fixture(scope, id)
    call = %SwarmAi.ToolCall{id: "write", name: "write_file", arguments: "{}"}
    {:ok, _} = Tasks.request_client_tool(scope, id, turn, call, :synchronous)
    assert :ok = Tasks.start_mcp_attempt(scope, id, call.id, 1)
    assert {:error, :stale_attempt} = Tasks.request_mcp_cancellation(scope, id, call.id, "1")
    assert :ok = Tasks.request_mcp_cancellation(scope, id, call.id, 1)
    assert :ok = Tasks.request_mcp_cancellation(scope, id, call.id, 1)
    assert {:error, :cancelled} = Tasks.start_mcp_attempt(scope, id, call.id, 2)
    assert {:ok, ^turn, [stored]} = Tasks.get_active_turn_unresolved_tool_calls(scope, id)
    assert stored.cancel_requested
    assert stored.outcome == :outcome_unknown
    assert stored.attempt_id == "1"
  end
end
