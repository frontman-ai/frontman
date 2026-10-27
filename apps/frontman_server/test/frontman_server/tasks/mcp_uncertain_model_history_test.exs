defmodule FrontmanServer.Tasks.MCPUncertainModelHistoryTest do
  use FrontmanServer.DataCase, async: false
  use FrontmanServer.ExecutionCase
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses

  setup do
    scope = user_scope_fixture()
    id = task_fixture(scope).id
    %{scope: scope, id: id, turn: start_turn_fixture(scope, id)}
  end

  test "uncertainty follows a declaration stored after dispatch", %{
    scope: scope,
    id: id,
    turn: turn
  } do
    call = cancelled_call(scope, id, turn, "write")
    record_error(id, turn)
    messages = continue_history(scope, id)
    assert Enum.map(messages, & &1.role) == [:system, :user, :assistant, :tool, :user]
    [tool] = Enum.filter(messages, &(&1.role == :tool))
    assert tool.tool_call_id == call.id
    assert Enum.any?(tool.content, &String.contains?(&1.text, "Outcome unknown"))
  end

  for additional_call <- [false, true] do
    @additional_call additional_call
    test "same-turn retries pair cancelled calls once, additional call: #{additional_call}",
         %{scope: scope, id: id, turn: turn} do
      cancelled_call(scope, id, turn, "first")
      error = record_error(id, turn)
      record_interaction(id, turn, :agent_retry, %{retried_error_id: error.data.id})

      if @additional_call, do: cancelled_call(scope, id, turn, "second")
      record_error(id, turn)

      messages = continue_history(scope, id)
      tools = Enum.filter(messages, &(&1.role == :tool))
      expected_ids = if @additional_call, do: ["first", "second"], else: ["first"]
      assert Enum.map(tools, & &1.tool_call_id) == expected_ids

      expected_roles =
        if @additional_call,
          do: [:system, :user, :assistant, :tool, :assistant, :tool, :user],
          else: [:system, :user, :assistant, :tool, :user]

      assert Enum.map(messages, & &1.role) == expected_roles

      assert Enum.all?(tools, fn tool ->
               Enum.any?(tool.content, &String.contains?(&1.text, "Outcome unknown"))
             end)
    end
  end

  test "actual evidence received during retry replaces uncertainty",
       %{scope: scope, id: id, turn: turn} do
    call = cancelled_call(scope, id, turn, "first")
    error = record_error(id, turn)
    record_interaction(id, turn, :agent_retry, %{retried_error_id: error.data.id})

    assert {:ok, _, _} =
             Tasks.resolve_tool_request(scope, id, call, %{
               "content" => [%{"type" => "text", "text" => "Write completed"}]
             })

    record_error(id, turn)
    messages = continue_history(scope, id)
    assert Enum.map(messages, & &1.role) == [:system, :user, :assistant, :tool, :user]
    [tool] = Enum.filter(messages, &(&1.role == :tool))
    assert tool.tool_call_id == call.id
    assert Enum.map(tool.content, & &1.text) == ["Write completed"]
  end

  defp cancelled_call(scope, id, turn, call_id) do
    call = %SwarmAi.ToolCall{id: call_id, name: "write_file", arguments: "{}"}
    {:ok, _} = Tasks.request_client_tool(scope, id, turn, call, :synchronous)

    {:ok, _} =
      Tasks.agent_replied(scope, id, turn, "", %{
        "tool_calls" => [%{"id" => call.id, "name" => call.name, "arguments" => call.arguments}]
      })

    {:ok, _} = Tasks.start_tool_attempt(scope, id, {turn, call.id}, "attempt")
    {:ok, _} = Tasks.request_tool_cancellation(scope, id, {turn, call.id}, "attempt")
    call
  end

  defp record_error(id, turn) do
    record_interaction(id, turn, :agent_error, %{kind: "cancelled", error: "Cancelled"})
  end

  defp record_interaction(id, turn, type, data) do
    interaction_changeset(id, %{
      id: Ecto.UUID.generate(),
      type: type,
      turn_number: turn,
      data: data
    })
    |> Repo.insert!()
  end

  defp continue_history(scope, id) do
    start_turn_fixture(scope, id, user_content("continue"))
    parent = self()

    Mox.expect(LLMProviderMock, :stream_text, fn _, messages, _ ->
      send(parent, {:model_history, messages})
      ReqLLMResponses.response("done")
    end)

    assert :ok = Tasks.resume_execution(scope, id, execution_request_fixture())
    assert_receive {:model_history, messages}, 1_000
    refute_running_eventually(id)
    messages
  end
end
