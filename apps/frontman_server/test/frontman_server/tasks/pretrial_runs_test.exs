defmodule FrontmanServer.Tasks.PretrialRunsTest do
  use FrontmanServerWeb.ChannelCase, async: false

  import FrontmanServer.ExecutionCase, only: [refute_running_eventually: 1]
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.{Accounts, Billing, Providers, Tasks}
  alias FrontmanServer.Test.Fixtures.LLMProvider

  test "five turns are shared across projects and survive conversation deletion", %{scope: scope} do
    {first, first_id} = join_task_channel(scope)
    {second, second_id} = join_task_channel(scope, framework: "wordpress")
    complete_mcp_handshake(first)
    complete_mcp_handshake(second, load_project_context: false)

    for socket <- [first, second, first, second, first], do: run_turn(socket)
    assert :ok = Tasks.delete_task(scope, first_id)
    assert %{pretrial_runs_remaining: 0} = Billing.status(scope)

    flush_mailbox()
    ref = push(second, "acp:message", build_prompt_request())
    assert_reply(ref, :ok, %{"acp:message" => %{"error" => %{}}})
    refute_push("acp:message", %{"params" => %{"update" => %{"state" => "running"}}})

    {other, _} = join_task_channel(user_scope_fixture())
    complete_mcp_handshake(other)
    run_turn(other)
    refute_running_eventually(second_id)
  end

  test "queued sixth turn starts automatically after the subscription webhook", %{scope: scope} do
    {socket, task_id} = join_task_channel(scope)
    complete_mcp_handshake(socket)
    for _ <- 1..4, do: run_turn(socket)

    {queued, queued_id} = join_task_channel(scope)
    accept_prompt(queued, id: 5)

    accept_prompt(queued,
      id: 6,
      _meta: %{
        "model" => %{"provider" => "openrouter", "value" => "google/gemini-3.1-pro-preview"},
        "agent" => "test-planner"
      }
    )

    complete_mcp_handshake(queued)
    assert_idle(queued_id)

    assert_push("acp:message", %{
      "params" => %{"update" => %{"sessionUpdate" => "error", "category" => "frontman_billing"}}
    })

    assert %{pretrial_runs_remaining: 0} = Billing.status(scope)
    assert {:ok, :processed} = activate_trial(scope)
    assert_idle(queued_id)
    refute_running_eventually(task_id)
  end

  for subscription <- [:none, :canceled] do
    @tag subscription: subscription
    test "a failed fifth turn retries with #{subscription} subscription", %{
      scope: scope,
      subscription: subscription
    } do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      for _ <- 1..4, do: run_turn(socket)

      Mox.stub(Tasks.Execution.LLMProviderMock, :stream_text, fn _, _, _ ->
        {:error, :test_failure}
      end)

      accept_prompt(socket)
      assert_push("acp:message", %{"params" => %{"update" => %{"sessionUpdate" => "error"}}})
      refute_running_eventually(task_id)
      assert %{pretrial_runs_remaining: 0} = Billing.status(scope)

      {:ok, task} = Tasks.get_task_with_history(scope, task_id)
      error = Enum.find(Enum.reverse(task.interaction_rows), &(&1.type == :agent_error))

      case subscription do
        :none ->
          :ok

        :canceled ->
          FrontmanServer.BillingFixtures.subscription_for_scope_fixture(scope, %{
            status: "canceled"
          })
      end

      execution = execution_request_fixture()
      LLMProvider.stub_llm_response("Retried")
      assert :ok = Tasks.retry_execution(scope, task_id, error.data.id, execution)
      assert_idle(task_id)
      {:ok, history} = Tasks.get_task_with_history(scope, task_id)
      assert Enum.count(history.interaction_rows, &(&1.type == :turn_started)) == 5
    end
  end

  test "missing credentials leave the allowance available for the eventual turn" do
    scope = Accounts.Scope.for_user(user_fixture())
    task = task_fixture(scope)
    execution = execution_request_fixture()
    execution_with_prompt(scope, task.id)

    assert {:error, :no_api_key} = Tasks.execute_next_turn(scope, task.id, execution)
    assert %{pretrial_runs_remaining: 5} = Billing.status(scope)

    :ok = Providers.upsert_api_key(scope, "openrouter", "sk-or-test")
    assert :ok = Tasks.execute_next_turn(scope, task.id, execution)
    refute_running_eventually(task.id)
    assert %{pretrial_runs_remaining: 4} = Billing.status(scope)
  end

  defp execution_with_prompt(scope, task_id) do
    execution = execution_request_fixture()

    assert {:ok, _} =
             Tasks.submit_user_message(
               scope,
               Map.merge(execution, %{
                 task_id: task_id,
                 message_id: Ecto.UUID.generate(),
                 message: user_content("Edit")
               })
             )

    execution
  end

  defp accept_prompt(socket, opts \\ []) do
    ref = push(socket, "acp:message", build_prompt_request(opts))
    assert_reply(ref, :ok, %{"acp:message" => %{"result" => %{}}})
  end

  defp run_turn(socket) do
    accept_prompt(socket)
    assert_idle(socket.assigns.task_id)
  end

  defp assert_idle(task_id) do
    assert_push(
      "acp:message",
      %{
        "params" => %{"sessionId" => ^task_id, "update" => %{"state" => "idle"}}
      },
      1_000
    )

    refute_running_eventually(task_id)
  end

  defp activate_trial(scope) do
    Billing.Webhooks.process_event(%{
      "id" => "evt_#{Ecto.UUID.generate()}",
      "type" => "customer.subscription.created",
      "data" => %{
        "object" => %{
          "id" => "sub_#{Ecto.UUID.generate()}",
          "customer" => "cus_#{Ecto.UUID.generate()}",
          "status" => "trialing",
          "metadata" => %{"user_id" => scope.user.id}
        }
      }
    })
  end
end
