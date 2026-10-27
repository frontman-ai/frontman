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
    logical_id = {turn, call.id}
    assert {:ok, _} = Tasks.start_tool_attempt(scope, id, logical_id, "first")

    assert {:error, :stale_attempt} =
             Tasks.request_tool_cancellation(scope, id, logical_id, "other")

    assert {:ok, cancelled} = Tasks.request_tool_cancellation(scope, id, logical_id, "first")
    assert {:ok, ^cancelled} = Tasks.request_tool_cancellation(scope, id, logical_id, "first")
    assert {:error, :cancelled} = Tasks.start_tool_attempt(scope, id, logical_id, "next")
    assert {:ok, ^turn, [stored]} = Tasks.get_active_turn_unresolved_tool_calls(scope, id)
    assert stored == cancelled
    assert stored.cancel_requested
    assert stored.outcome == :outcome_unknown
    assert stored.attempt_id == "first"
    {:ok, _, _} = Tasks.resolve_tool_request(scope, id, call, %{"content" => []})
    {:ok, _} = Tasks.record_execution_outcome(scope, id, turn, :completed)
    next_turn = start_turn_fixture(scope, id)
    {:ok, _} = Tasks.request_client_tool(scope, id, next_turn, call, :synchronous)
    assert {:ok, _} = Tasks.start_tool_attempt(scope, id, {next_turn, call.id}, "next")
  end
end
