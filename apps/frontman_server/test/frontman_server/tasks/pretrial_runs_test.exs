defmodule FrontmanServer.Tasks.PretrialRunsTest do
  use FrontmanServer.ExecutionCase

  import FrontmanServer.DataCase, only: [setup_sandbox: 1]
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.BillingFixtures
  import Mox

  alias FrontmanServer.{Accounts, Billing, Repo, Tasks}
  alias FrontmanServer.Tasks.{Interaction, InteractionSchema}

  setup [:setup_sandbox, :setup_user]

  test "five BYOK runs survive deletion, finish and retry at zero, then queued work waits for trial",
       %{scope: scope} do
    expect_llm_responses(List.duplicate("Done", 4))

    for remaining <- 4..1//-1 do
      task = task_with_pubsub_fixture(scope)

      assert {:ok, _, 1} =
               submit_user_message_and_run(
                 scope,
                 task.id,
                 execution_request_fixture(),
                 user_content("Edit")
               )

      assert_receive {:interaction, %{data: %Interaction.AgentCompleted{}}}, 1_000
      refute_running_eventually(task.id)
      assert :ok = Tasks.delete_task(scope, task.id)
      assert %{pretrial_runs_remaining: ^remaining} = Billing.status(scope)
    end

    task = task_with_pubsub_fixture(scope)
    execution = execution_request_fixture()

    for agent <- ["test-frontman", "test-planner"] do
      assert {:ok, _} =
               Tasks.submit_user_message(
                 scope,
                 Map.merge(execution, %{
                   task_id: task.id,
                   message_id: Ecto.UUID.generate(),
                   message: user_content("Edit"),
                   agent_id: agent
                 })
               )
    end

    parent = self()

    expect(FrontmanServer.Tasks.Execution.LLMProviderMock, :stream_text, fn _, _, opts ->
      assert opts[:api_key] == "sk-or-test"
      send(parent, {:fifth_started, self()})

      receive do
        :fail -> {:error, :test_failure}
      after
        2_000 -> raise "Test did not release the fifth run"
      end
    end)

    assert :ok = Tasks.execute_next_turn(scope, task.id, execution)
    assert_receive {:fifth_started, provider}, 1_000
    assert %{pretrial_runs_remaining: 0, access_allowed: false} = Billing.status(scope)
    assert {:error, :already_running} = Tasks.resume_execution(scope, task.id, execution)
    send(provider, :fail)
    assert_receive {:interaction, %{data: %Interaction.AgentError{id: error_id}}}, 1_000
    refute_running_eventually(task.id)

    expect_llm_responses(["Retried"])
    assert :ok = Tasks.retry_execution(scope, task.id, error_id, execution)
    assert_receive {:interaction, %{data: %Interaction.AgentCompleted{}}}, 1_000
    refute_running_eventually(task.id)
    assert %{pretrial_runs_remaining: 0} = Billing.status(scope)
    assert {:error, :billing_inactive} = Tasks.execute_next_turn(scope, task.id, execution)

    assert Repo.aggregate(
             InteractionSchema.for_task(task.id) |> InteractionSchema.of_type(:turn_started),
             :count
           ) == 1

    assert {:error, :billing_inactive} =
             Tasks.submit_user_message(
               scope,
               Map.merge(execution, %{
                 task_id: task.id,
                 message_id: Ecto.UUID.generate(),
                 message: user_content("Sixth")
               })
             )

    subscription_for_scope_fixture(scope, %{status: "trialing"})
    expect_llm_responses(["Queued run after trial"])
    assert :ok = Tasks.execute_next_turn(scope, task.id, execution)
    assert_receive {:interaction, %{data: %Interaction.AgentCompleted{}}}, 1_000
    refute_running_eventually(task.id)
    assert %{used: 5} = Repo.get!(Billing.RunAllowance, scope.user.id)
  end

  test "recovery resumes a persisted fifth run after its process is gone", %{scope: scope} do
    task = task_with_pubsub_fixture(scope)
    message = insert_accepted_user_message!(task, "Recover")

    interaction_changeset(task.id, %{
      id: Ecto.UUID.generate(),
      type: :turn_started,
      turn_number: 1,
      data: %{agent_id: "test-frontman", user_message_ids: [message.id], pretrial_run: true}
    })
    |> Repo.insert!()

    for _ <- 1..5, do: :ok = Billing.consume_pretrial_run(scope)
    refute SwarmAi.running?(FrontmanServer.AgentRuntime, task.id)
    expect_llm_responses(["Recovered"])
    assert :ok = Tasks.resume_execution(scope, task.id, execution_request_fixture())
    assert_receive {:interaction, %{data: %Interaction.AgentCompleted{}}}, 1_000
    refute_running_eventually(task.id)
    assert %{pretrial_runs_remaining: 0} = Billing.status(scope)
  end

  test "no provider credentials means no run and no allowance consumed" do
    scope = Accounts.Scope.for_user(user_fixture())
    task = task_fixture(scope)

    assert {:error, :no_api_key} =
             submit_user_message_and_run(
               scope,
               task.id,
               execution_request_fixture(),
               user_content("Edit")
             )

    assert %{pretrial_runs_remaining: 5} = Billing.status(scope)

    assert Repo.aggregate(
             InteractionSchema.for_task(task.id) |> InteractionSchema.of_type(:turn_started),
             :count
           ) == 0
  end

  test "ownership checks prevent consuming another user's allowance", %{scope: scope} do
    task = task_fixture(user_scope_fixture())

    assert {:error, :not_found} =
             Tasks.execute_next_turn(scope, task.id, execution_request_fixture())

    assert %{pretrial_runs_remaining: 5} = Billing.status(scope)
  end
end
