defmodule FrontmanServer.Tasks.PretrialRunsTest do
  use FrontmanServerWeb.ChannelCase, async: false

  import FrontmanServer.ExecutionCase, only: [refute_running_eventually: 1]
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.{Accounts, Billing, Tasks}
  alias FrontmanServer.Test.Fixtures.LLMProvider

  test "user-wide allowance survives deletion; fifth turn retries and queued sixth waits for billing",
       %{scope: scope} do
    {first, first_id} = join_task_channel(scope)
    {second, _} = join_task_channel(scope, framework: "wordpress")
    complete_mcp_handshake(first)
    complete_mcp_handshake(second, load_project_context: false)
    for socket <- [first, second, first, second], do: run_turn(socket)
    Process.unlink(first.channel_pid)
    ref = leave(first)
    assert_reply(ref, :ok)
    assert :ok = Tasks.delete_task(scope, first_id)
    assert %{pretrial_runs_remaining: 1} = Billing.status(scope)

    {queued, queued_id} = join_task_channel(scope)
    accept_prompt(queued)

    accept_prompt(queued,
      _meta: %{
        "model" => %{"provider" => "openrouter", "value" => "google/gemini-3.1-pro-preview"},
        "agent" => "test-planner"
      }
    )

    LLMProvider.expect_llm_responses([{:error, :test_failure}, "Retried", "Queued", "Other user"])
    complete_mcp_handshake(queued)
    assert_billing_blocked()
    assert %{pretrial_runs_remaining: 0} = Billing.status(scope)
    ref = push(second, "acp:message", build_prompt_request())
    assert_reply(ref, :ok, %{"acp:message" => %{"error" => %{}}})

    {:ok, task} = Tasks.get_task_with_history(scope, queued_id)
    error = Enum.find(task.interaction_rows, &(&1.type == :agent_error))
    assert {:ok, :processed} = subscription_event(scope, "canceled")

    assert :ok =
             Tasks.retry_execution(scope, queued_id, error.data.id, execution_request_fixture())

    assert_idle(queued_id)
    assert_billing_blocked()
    assert {:ok, :processed} = subscription_event(scope, "trialing")
    assert_idle(queued_id)

    {other, _} = join_task_channel(user_scope_fixture())
    complete_mcp_handshake(other)
    run_turn(other)
  end

  test "missing credentials do not consume an allowance" do
    scope = Accounts.Scope.for_user(user_fixture())
    task = task_fixture(scope)
    insert_accepted_user_message!(task, "Edit")

    assert {:error, :no_api_key} =
             Tasks.execute_next_turn(scope, task.id, execution_request_fixture())

    assert %{pretrial_runs_remaining: 5} = Billing.status(scope)
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

  defp assert_billing_blocked do
    assert_push(
      "acp:message",
      %{
        "params" => %{"update" => %{"sessionUpdate" => "error", "category" => "frontman_billing"}}
      },
      1_000
    )
  end

  defp subscription_event(scope, status) do
    Billing.Webhooks.process_event(%{
      "id" => "evt_#{Ecto.UUID.generate()}",
      "type" => "customer.subscription.updated",
      "data" => %{
        "object" => %{
          "id" => "sub_#{scope.user.id}",
          "customer" => "cus_#{scope.user.id}",
          "status" => status,
          "metadata" => %{"user_id" => scope.user.id}
        }
      }
    })
  end
end
