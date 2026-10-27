defmodule FrontmanServer.Tasks.MCPUncertainModelHistoryTest do
  use FrontmanServer.DataCase, async: false
  use FrontmanServer.ExecutionCase
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses

  test "uncertainty is projected at the turn boundary, after a late declaration" do
    scope = user_scope_fixture()
    id = task_fixture(scope).id
    turn = start_turn_fixture(scope, id)
    call = %SwarmAi.ToolCall{id: "write", name: "write_file", arguments: "{}"}
    {:ok, _} = Tasks.request_client_tool(scope, id, turn, call, :synchronous)

    {:ok, _} =
      Tasks.agent_replied(scope, id, turn, "", %{
        "tool_calls" => [%{"id" => call.id, "name" => call.name, "arguments" => call.arguments}]
      })

    :ok = Tasks.start_mcp_attempt(scope, id, {turn, call.id}, 1)
    :ok = Tasks.request_mcp_cancellation(scope, id, {turn, call.id}, 1)

    interaction_changeset(id, %{
      id: Ecto.UUID.generate(),
      type: :agent_error,
      turn_number: turn,
      data: %{kind: "cancelled", error: "Cancelled"}
    })
    |> Repo.insert!()

    start_turn_fixture(scope, id, user_content("continue"))
    parent = self()

    Mox.expect(LLMProviderMock, :stream_text, fn _, messages, _ ->
      send(parent, {:model_history, messages})
      ReqLLMResponses.response("done")
    end)

    assert :ok = Tasks.resume_execution(scope, id, execution_request_fixture())
    assert_receive {:model_history, messages}, 1_000
    assert Enum.map(messages, & &1.role) == [:system, :user, :assistant, :tool, :user]
    tool = Enum.find(messages, &(&1.role == :tool))
    assert tool.tool_call_id == call.id
    assert Enum.any?(tool.content, &String.contains?(&1.text, "Outcome unknown"))
    refute_running_eventually(id)
  end
end
