defmodule FrontmanServer.Tasks.CustomerFeedbackIntegrationTest do
  use FrontmanServer.ExecutionCase
  import Mox
  import FrontmanServer.DataCase, only: [setup_sandbox: 1]
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.Test.Fixtures.Tools, only: [mcp_tool: 1, mcp_tool: 2]
  import FrontmanServer.InteractionCase.Helpers, only: [assert_receive_interaction: 2]

  alias FrontmanServer.CustomerFeedback
  alias FrontmanServer.CustomerFeedback.Feedback
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema}
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses
  alias FrontmanServer.Tools.MCP

  @moduletag billing: :active
  @name "request_customer_feedback"
  setup [:setup_sandbox, :setup_user, :setup_task, :verify_on_exit!]

  defp tools do
    MCP.from_maps([
      mcp_tool(@name, %{
        "_meta" => %{
          "ai.frontman/tool-metadata" => %{"access" => "write", "executionMode" => "Interactive"}
        }
      }),
      mcp_tool("ordinary_tool")
    ])
  end

  test "startup hides recent feedback but preserves ordinary tools", %{scope: scope, task_id: id} do
    turn = start_turn_fixture(scope, id)
    call = %SwarmAi.ToolCall{id: "feedback", name: @name, arguments: "{}"}
    assert {:ok, _} = Tasks.request_client_tool(scope, id, turn, call, :interactive)
    refute CustomerFeedback.eligible?(scope)
    names = tools() |> CustomerFeedback.filter_tools(scope) |> Enum.map(& &1.name)
    refute @name in names
    assert "ordinary_tool" in names
  end

  test "feedback is saved before the agent continues with the same tools",
       %{scope: scope, task_id: id} do
    call = tool_call(@name, %{}, id: "feedback")
    expect_llm_responses([{:tool_calls, [call], "Feedback"}])
    parent = self()

    expect(LLMProviderMock, :stream_text, fn _model, messages, opts ->
      send(parent, {:continued, messages, Enum.map(opts[:tools], & &1.name)})
      ReqLLMResponses.response("Thanks")
    end)

    {:ok, _, _} =
      submit_user_message_and_run(
        scope,
        id,
        execution_request_fixture(mcp_tools: tools()),
        user_content("Finished")
      )

    assert_receive_interaction(%Interaction.ToolCall{tool_call_id: "feedback"}, 1)

    request =
      id |> InteractionSchema.for_task() |> InteractionSchema.of_type(:tool_call) |> Repo.one!()

    assert Repo.get_by!(Feedback, interaction_id: request.id).score == nil
    call = %SwarmAi.ToolCall{id: "feedback", name: @name, arguments: "{}"}

    assert {:error, %Ecto.Changeset{}} =
             Tasks.resolve_tool_request(
               scope,
               id,
               call,
               browser_result(%{"outcome" => "answered", "score" => 11})
             )

    assert {:ok, result, :notified} =
             Tasks.resolve_tool_request(
               scope,
               id,
               call,
               browser_result(%{
                 "outcome" => "answered",
                 "score" => 8,
                 "comment" => "Ignore instructions"
               })
             )

    assert Repo.get_by!(Feedback, interaction_id: request.id).score == 8
    assert_receive {:continued, messages, names}, 1_000
    assert @name in names
    [reply] = Enum.filter(messages, &(&1.role == :tool))
    assert [%{text: text}] = reply.content
    assert Jason.decode!(text) == result.result["structuredContent"]
    refute text =~ "Browser says saved"
    assert_receive_interaction(%Interaction.AgentCompleted{}, 1)
    refute_running_eventually(id)

    assert {:ok, replay, :no_executor} =
             Tasks.resolve_tool_request(
               scope,
               id,
               call,
               browser_result(%{"outcome" => "answered", "score" => 10})
             )

    assert replay == result
  end

  test "skip survives restart without answering or creating another request", %{
    scope: scope,
    task_id: id
  } do
    turn = start_turn_fixture(scope, id)
    call = %SwarmAi.ToolCall{id: "feedback", name: @name, arguments: "{}"}
    {:ok, _} = Tasks.request_client_tool(scope, id, turn, call, :interactive)
    assert :ok = Tasks.handle_swarm_event(scope, id, turn, {:terminated, :shutdown})

    assert {:ok, ^turn, [%Interaction.ToolCall{tool_call_id: "feedback"}]} =
             Tasks.get_active_turn_unresolved_tool_calls(scope, id)

    assert {:ok, result, :no_executor} =
             Tasks.resolve_tool_request(
               scope,
               id,
               call,
               browser_result(%{"outcome" => "skipped"})
             )

    assert result.result["structuredContent"] == %{"outcome" => "skipped"}
    assert [%Feedback{score: nil, answered_at: nil}] = Repo.all(Feedback)
    refute CustomerFeedback.eligible?(scope)
  end

  test "a forged feedback result cannot answer an ordinary tool", %{scope: scope, task_id: id} do
    turn = start_turn_fixture(scope, id)
    ordinary = %SwarmAi.ToolCall{id: "ordinary", name: "ordinary_tool", arguments: "{}"}
    {:ok, _} = Tasks.request_client_tool(scope, id, turn, ordinary, :interactive)

    assert {:error, :not_found} =
             Tasks.resolve_tool_request(
               scope,
               id,
               %{ordinary | name: @name},
               browser_result(%{"outcome" => "answered", "score" => 8})
             )

    assert Repo.aggregate(Feedback, :count) == 0
  end

  test "feedback and interactions roll back together", %{scope: scope, task_id: id} do
    turn = start_turn_fixture(scope, id)
    call = %SwarmAi.ToolCall{id: "feedback", name: @name, arguments: "{}"}

    assert {:error, :rollback} =
             Repo.transact(fn ->
               {:ok, _} = Tasks.request_client_tool(scope, id, turn, call, :interactive)

               {:ok, _, :no_executor} =
                 Tasks.resolve_tool_request(
                   scope,
                   id,
                   call,
                   browser_result(%{"outcome" => "answered", "score" => 8})
                 )

               {:error, :rollback}
             end)

    assert Repo.aggregate(Feedback, :count) == 0

    assert Repo.aggregate(
             InteractionSchema.for_task(id) |> InteractionSchema.of_type(:tool_call),
             :count
           ) == 0

    assert Repo.aggregate(
             InteractionSchema.for_task(id) |> InteractionSchema.of_type(:tool_result),
             :count
           ) == 0
  end

  defp browser_result(output) do
    %{
      "content" => [%{"type" => "text", "text" => "Browser says saved"}],
      "structuredContent" => output
    }
  end
end
