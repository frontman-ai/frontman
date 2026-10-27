defmodule FrontmanServer.ApplicationRestartTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  import Mox
  import SwarmAi.Testing, only: [tool_call: 3]

  import FrontmanServer.ExecutionCase,
    only: [submit_user_message_and_run: 4, refute_running_eventually: 1]

  import FrontmanServer.InteractionCase.Helpers,
    only: [assert_receive_interaction: 2, extract_content_text: 1]

  import FrontmanServer.Test.Fixtures.LLMProvider
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Protocols
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema}
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses
  alias FrontmanServer.Tools.MCP

  setup do
    Process.flag(:trap_exit, true)
    Mox.set_mox_global()
    {:ok, user} = Accounts.register_user(%{email: "restart@example.com", name: "Restart"})
    scope = Scope.for_user(user)
    :ok = FrontmanServer.Providers.upsert_api_key(scope, "openrouter", "sk-or-test")
    FrontmanServer.BillingFixtures.run_allowance_fixture(scope, 4)
    task_id = task_with_pubsub_fixture(scope, framework: "wordpress").id
    %{scope: scope, task_id: task_id}
  end

  test "application shutdown preserves approval and resumes the fifth turn with no allowance left",
       %{scope: scope, task_id: task_id} do
    approval = tool_call("approval", %{}, id: "approval_serial")
    write = tool_call("write_file", %{}, id: "write_serial")

    tools =
      MCP.from_maps([
        %{
          "name" => "approval",
          "_meta" => %{"ai.frontman/tool-metadata" => %{"executionMode" => "Interactive"}}
        },
        %{"name" => "write_file"}
      ])

    parent = self()
    expect_llm_responses([{:tool_calls, [approval, write], "Approve first"}])

    expect(LLMProviderMock, :stream_text, fn model, messages, _opts ->
      send(parent, {:resumed_messages, model, messages})
      ReqLLMResponses.response("Recovered")
    end)

    {:ok, _, 1} =
      submit_user_message_and_run(
        scope,
        task_id,
        execution_request_fixture(mcp_tools: tools),
        user_content("Do the change")
      )

    assert_parked(scope, task_id)

    assert_enqueued(
      worker: FrontmanServer.Workers.SyncResendContact,
      args: %{user_id: scope.user.id, activation: true}
    )

    restart_application(task_id)
    assert_pending(scope, task_id)
    resolve_and_resume(scope, task_id, approval, tools)
    assert_recovered_history(write, approval)
    assert_receive_interaction(%Interaction.AgentCompleted{}, 1)
    refute_running_eventually(task_id)
    assert %{pretrial_runs_remaining: 0} = FrontmanServer.Billing.status(scope)

    assert 1 ==
             task_id
             |> InteractionSchema.for_task()
             |> InteractionSchema.of_type(:turn_started)
             |> Repo.aggregate(:count)

    refute_receive {:interaction, %{data: %Interaction.ToolCall{tool_name: "write_file"}}}, 50
  end

  defp assert_parked(scope, task_id) do
    assert_receive_interaction(
      %Interaction.ToolCall{tool_name: "approval", execution_mode: :interactive},
      1
    )

    refute_receive {:interaction, %{data: %Interaction.ToolCall{tool_name: "write_file"}}}, 250
    {:ok, waiting} = Tasks.get_task_with_history(scope, task_id)
    refute Enum.any?(Tasks.interactions(waiting), &match?(%Interaction.ToolResult{}, &1))
    refute Enum.any?(Tasks.interactions(waiting), &match?(%Interaction.AgentPaused{}, &1))
    assert_active_count(0)
    assert SwarmAi.running?(FrontmanServer.AgentRuntime, task_id)
  end

  defp restart_application(task_id) do
    repo = Process.whereis(Repo)
    runtime = Process.whereis(FrontmanServer.AgentRuntime)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        assert :ok = Application.stop(:frontman_server)
      end)

    refute log =~ "unknown registry"
    refute Process.alive?(repo)
    refute Process.alive?(runtime)
    {:ok, _} = Application.ensure_all_started(:frontman_server)
    :ok = Phoenix.PubSub.subscribe(FrontmanServer.PubSub, "task:#{task_id}")
  end

  defp assert_pending(scope, task_id) do
    assert_receive_interaction(
      %Interaction.ToolResult{tool_name: "write_file", is_error: true},
      1
    )

    refute_receive {:interaction, %{data: %Interaction.AgentError{}}}, 50
    {:ok, pending} = Tasks.get_task_with_history(scope, task_id)

    assert [%Interaction.ToolCall{tool_name: "approval"}] =
             Enum.filter(Tasks.interactions(pending), &match?(%Interaction.ToolCall{}, &1))

    assert {:ok, 1, [%Interaction.ToolCall{tool_name: "approval"}]} =
             Tasks.get_active_turn_unresolved_tool_calls(scope, task_id)

    assert {:error, :billing_inactive} =
             Tasks.submit_user_message(
               scope,
               Map.merge(execution_request_fixture(), %{
                 task_id: task_id,
                 message_id: Ecto.UUID.generate(),
                 message: user_content("New turns require billing")
               })
             )
  end

  defp resolve_and_resume(scope, task_id, approval, tools) do
    assert {:ok, _, _} =
             Tasks.resolve_tool_request(
               scope,
               task_id,
               approval,
               Protocols.MCP.tool_result_text("yes")
             )

    refute_running_eventually(task_id)
    assert_active_count(0)

    assert :ok =
             Tasks.resume_execution(
               scope,
               task_id,
               execution_request_fixture(model: "missing:connection-model", mcp_tools: tools)
             )
  end

  defp assert_recovered_history(write, approval) do
    assert_receive {:resumed_messages, %LLMDB.Model{id: "openai/gpt-5.5"}, messages}, 1_000
    results = Enum.filter(messages, &(&1.role == :tool))
    assert Enum.map(results, & &1.tool_call_id) == [write.id, approval.id]

    assert Enum.map(results, &extract_content_text(&1.content)) == [
             "Interrupted by restart",
             "yes"
           ]
  end

  defp assert_active_count(expected, attempts \\ 50)

  defp assert_active_count(expected, 0) do
    assert SwarmAi.active_count(FrontmanServer.AgentRuntime) == expected
  end

  defp assert_active_count(expected, attempts) do
    case SwarmAi.active_count(FrontmanServer.AgentRuntime) do
      ^expected ->
        :ok

      _count ->
        Process.sleep(10)
        assert_active_count(expected, attempts - 1)
    end
  end
end
