defmodule FrontmanServer.Tasks.MCPCancelledModelHistoryTest do
  use FrontmanServer.DataCase, async: false
  use FrontmanServer.ExecutionCase
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses

  for reconciled? <- [false, true] do
    test "model history pairs cancelled calls, reconciled=#{reconciled?}" do
      scope = user_scope_fixture()
      id = task_fixture(scope).id
      turn = start_turn_fixture(scope, id)
      call = %SwarmAi.ToolCall{id: "write", name: "write_file", arguments: "{}"}
      {:ok, _} = persist_response_tool_call_fixture(scope, id, turn, "", call)
      :ok = Tasks.start_mcp_attempt(scope, id, {turn, call.id}, 1)
      :ok = Tasks.handle_swarm_event(scope, id, turn, {:cancelled, :user})
      start_turn_fixture(scope, id, user_content("continue"))

      if unquote(reconciled?) do
        {:ok, _, :reconciled} =
          Tasks.resolve_tool_request(
            scope,
            id,
            call,
            %{
              "content" => [%{"type" => "text", "text" => "actual success"}]
            }, turn_number: turn)
      end

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
      expected = if unquote(reconciled?), do: "actual success", else: "Outcome unknown"
      assert Enum.any?(tool.content, &String.contains?(&1.text, expected))
      refute_running_eventually(id)
    end
  end
end
