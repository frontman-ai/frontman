defmodule FrontmanServer.Tasks.PretrialRunsTest do
  use FrontmanServerWeb.ChannelCase, async: false

  import FrontmanServer.ExecutionCase, only: [refute_running_eventually: 1]
  import FrontmanServer.Test.Fixtures.Tasks, only: [task_topic: 1]

  alias FrontmanServer.Billing
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Test.Fixtures.LLMProvider

  test "subscription webhook starts the exact message queued before allowance exhaustion", %{
    scope: scope
  } do
    {socket, task_id} = join_task_channel(scope)
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))
    message_id = Ecto.UUID.generate()
    ref = push(socket, "acp:message", build_prompt_request(message_id: message_id))
    assert_reply(ref, :ok, %{"acp:message" => %{"result" => %{}}})

    FrontmanServer.BillingFixtures.run_allowance_fixture(scope, 5)
    complete_mcp_handshake(socket)

    assert_push(
      "acp:message",
      %{
        "params" => %{"sessionId" => ^task_id, "update" => %{"category" => "frontman_billing"}}
      },
      1_000
    )

    refute_received {:interaction, %{task_id: ^task_id, type: :turn_started}}

    LLMProvider.expect_llm_responses(["Queued work completed"])

    assert {:ok, :processed} =
             Billing.Webhooks.process_event(%{
               "id" => "evt_#{scope.user.id}",
               "type" => "customer.subscription.created",
               "data" => %{
                 "object" => %{
                   "id" => "sub_#{scope.user.id}",
                   "customer" => "cus_#{scope.user.id}",
                   "status" => "trialing",
                   "metadata" => %{"user_id" => scope.user.id}
                 }
               }
             })

    assert_receive {:interaction,
                    %{
                      task_id: ^task_id,
                      turn_number: 1,
                      data: %Interaction.TurnStarted{user_message_ids: [^message_id]}
                    }},
                   1_000

    assert_receive {:interaction, %{task_id: ^task_id, turn_number: 1, type: :agent_completed}},
                   5_000

    refute_running_eventually(task_id)
  end
end
