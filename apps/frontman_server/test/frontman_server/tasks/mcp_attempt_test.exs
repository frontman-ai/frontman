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

  test "late actual evidence resolves once without reopening a cancelled turn" do
    scope = user_scope_fixture()
    id = task_fixture(scope).id
    turn = start_turn_fixture(scope, id)
    call = %SwarmAi.ToolCall{id: "late", name: "write_file", arguments: "{}"}
    {:ok, _} = Tasks.request_client_tool(scope, id, turn, call, :synchronous)
    {:ok, _} = Tasks.start_tool_attempt(scope, id, {turn, call.id}, "late")
    {:ok, _} = Tasks.request_tool_cancellation(scope, id, {turn, call.id}, "late")
    :ok = Tasks.handle_swarm_event(scope, id, turn, {:terminated, :shutdown})
    {:ok, task} = Tasks.get_task_with_history(scope, id)
    refute Enum.any?(Tasks.interactions(task), &match?(%Tasks.Interaction.ToolResult{}, &1))
    next_turn = start_turn_fixture(scope, id)

    Registry.register(FrontmanServer.ProcessRegistry, {:tool_call, id, call.id}, %{
      caller_pid: self()
    })

    result = %{"content" => [%{"type" => "text", "text" => "actual success"}]}

    assert {:ok, winner, :reconciled} =
             Tasks.resolve_tool_request(scope, id, call, result, turn_number: turn)

    assert {:ok, ^winner, :reconciled} =
             Tasks.resolve_tool_request(scope, id, call, %{"content" => []}, turn_number: turn)

    refute_receive {:tool_result, _, _, _}
    assert {:ok, ^next_turn, []} = Tasks.get_active_turn_unresolved_tool_calls(scope, id)
  end
end
