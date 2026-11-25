defmodule FrontmanServer.Tasks.EditEligibilityTest do
  use FrontmanServer.DataCase, async: true
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  alias FrontmanServer.{OpenAIAds, Repo, Tasks}
  alias FrontmanServer.OpenAIAds.Delivery

  test "only an explicit changed result in the completed turn claims the first edit" do
    scope = user_scope_fixture()
    task = task_fixture(scope)
    :ok = OpenAIAds.record(scope, "registration_completed", scope.user.id)
    claim = fn -> Repo.get_by(Delivery, user_id: scope.user.id, kind: "first_successful_edit") end

    for {fields, outcome} <- [
          {%{"changed" => true}, :cancelled},
          {%{"changed" => true}, {:failed, "failed"}},
          {%{}, :completed},
          {%{"changed" => false}, :completed},
          {%{"changed" => "true"}, :completed},
          {%{"changed" => true, "isError" => true}, :completed},
          {%{"structuredContent" => %{"changed" => true}}, :completed},
          {%{"content" => [%{"type" => "text", "text" => ~s({"changed":true})}]}, :completed}
        ] do
      turn = resolve_result(scope, task, "write_file", fields)
      assert {:ok, _} = Tasks.record_execution_outcome(scope, task.id, turn, outcome)
      refute claim.()
    end

    turn = resolve_result(scope, task, "new_tool", %{"changed" => true})
    refute claim.()
    assert {:ok, _} = Tasks.record_execution_outcome(scope, task.id, turn, :completed)
    assert %Delivery{} = claim.()
  end

  defp resolve_result(scope, task, name, fields) do
    turn = start_turn_fixture(scope, task.id)
    call = %SwarmAi.ToolCall{id: Ecto.UUID.generate(), name: name, arguments: "{}"}
    result = Map.put_new(fields, "content", [])
    assert {:ok, _} = Tasks.request_client_tool(scope, task.id, turn, call, :synchronous)
    assert {:ok, _, :no_executor} = Tasks.resolve_tool_request(scope, task.id, call, result)
    turn
  end
end
