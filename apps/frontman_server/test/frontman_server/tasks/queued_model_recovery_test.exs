defmodule FrontmanServer.Tasks.QueuedModelRecoveryTest do
  use FrontmanServer.ExecutionCase
  use Oban.Testing, repo: FrontmanServer.Repo

  import Mox
  import FrontmanServer.DataCase, only: [setup_sandbox: 1]
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Billing.RunAllowance
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.OAuthToken
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.{ErrorClassifier, LLMProviderMock}
  alias FrontmanServer.Tasks.{History, Interaction, InteractionSchema}
  alias FrontmanServer.Test.Fixtures.ReqLLMResponses
  alias FrontmanServer.Workers.GenerateTitle

  setup [:verify_on_exit!, :setup_sandbox]
  setup {Req.Test, :verify_on_exit!}

  setup do
    scope = user_scope_fixture()
    task = task_with_pubsub_fixture(scope)

    %OAuthToken{user_id: scope.user.id}
    |> OAuthToken.changeset(%{
      provider: "openai_codex",
      access_token: "test-access",
      refresh_token: "test-refresh",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      metadata: %{"account_id" => "test-account"}
    })
    |> Repo.insert!()

    %{scope: scope, task: task}
  end

  test "unavailable queued group terminates without billing or inference and next model proceeds",
       %{scope: scope, task: task} do
    Req.Test.expect(:openai_oauth, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/backend-api/codex/models"
      Req.Test.json(conn, %{"models" => [%{"slug" => "gpt-6-sol", "visibility" => "list"}]})
    end)

    first = submit(scope, task.id, "openai_codex:gpt-6-astra")
    second = submit(scope, task.id, "openai_codex:gpt-6-astra")
    supported = submit(scope, task.id, "openrouter:openai/gpt-5.5")
    refute Repo.get(RunAllowance, scope.user.id)

    # No provider expectation exists until after the rejected turn has finished.
    assert :ok = Tasks.execute_next_turn(scope, task.id, execution_request_fixture())

    assert_receive {:interaction,
                    %InteractionSchema{type: :turn_started, turn_number: 1} = started}

    assert started.data.agent_id == "test-frontman"
    assert started.data.user_message_ids == [first.id, second.id]
    assert_receive {:interaction, %InteractionSchema{type: :agent_error, turn_number: 1} = error}
    {message, category, retryable} = ErrorClassifier.classify_error(:unknown_model)
    assert error.data.error == message
    assert error.data.kind == "rejected"
    assert error.data.category == category
    assert error.data.retryable == retryable
    # The rejection is committed with the turn claim before either event is published.
    assert {:ok, _turn} = History.turn(history(task.id), 1)
    assert History.active_turn_number(history(task.id)) == nil
    refute Repo.get(RunAllowance, scope.user.id)
    refute_enqueued(worker: GenerateTitle)
    refute SwarmAi.running?(FrontmanServer.AgentRuntime, task.id)
    assert [pending] = history(task.id) |> History.pending_accepted_messages()
    assert pending.id == supported.id

    # Availability can recover, but this turn was never authorized for inference.
    Req.Test.expect(:openai_oauth, fn conn ->
      Req.Test.json(conn, %{"models" => [%{"slug" => "gpt-6-astra", "visibility" => "list"}]})
    end)

    assert {:ok, _access} = Providers.resolve_model_access(scope, "openai_codex:gpt-6-astra")
    before_retry = history(task.id).rows

    assert {:error, :turn_not_authorized} =
             Tasks.retry_execution(scope, task.id, error.data.id, execution_request_fixture())

    assert {:error, :not_running} =
             Tasks.resume_execution(scope, task.id, execution_request_fixture())

    assert history(task.id).rows == before_retry
    refute Repo.get(RunAllowance, scope.user.id)
    refute SwarmAi.running?(FrontmanServer.AgentRuntime, task.id)

    expect(LLMProviderMock, :stream_text, fn model, _messages, opts ->
      assert model.id == "openai/gpt-5.5"
      assert opts[:api_key] == "sk-or-test"
      ReqLLMResponses.response("Supported prompt completed.")
    end)

    assert :ok = Tasks.execute_next_turn(scope, task.id, execution_request_fixture())
    assert_receive {:interaction, %InteractionSchema{type: :turn_started, turn_number: 2} = next}
    assert next.data.user_message_ids == [supported.id]

    assert_receive {:interaction,
                    %InteractionSchema{data: %Interaction.AgentCompleted{}, turn_number: 2}},
                   5_000

    assert %RunAllowance{used: 1} = Repo.get!(RunAllowance, scope.user.id)
    assert_enqueued(worker: GenerateTitle, args: %{"model" => "openrouter:openai/gpt-5.5"})
    assert History.pending_accepted_messages(history(task.id)) == []
    refute_running_eventually(task.id)
  end

  test "discovery outage leaves the accepted queue and allowance untouched",
       %{scope: scope, task: task} do
    Req.Test.stub(:openai_oauth, fn conn ->
      assert conn.method == "GET"
      conn |> Plug.Conn.put_status(503) |> Req.Test.json(%{"error" => "outage"})
    end)

    submit(scope, task.id, "openai_codex:gpt-6-astra")
    submit(scope, task.id, "openrouter:openai/gpt-5.5")
    before = history(task.id).rows

    assert {:error, :model_discovery_failed} =
             Tasks.execute_next_turn(scope, task.id, execution_request_fixture())

    assert history(task.id).rows == before
    refute Repo.get(RunAllowance, scope.user.id)
    refute_enqueued(worker: GenerateTitle)
    refute_receive {:interaction, %InteractionSchema{type: :turn_started}}
    refute_receive {:interaction, %InteractionSchema{type: :agent_error}}
    refute SwarmAi.running?(FrontmanServer.AgentRuntime, task.id)
  end

  defp submit(scope, task_id, model) do
    {:ok, row} =
      Tasks.submit_user_message(scope, %{
        task_id: task_id,
        message_id: Ecto.UUID.generate(),
        message: user_content("Queued prompt"),
        model: model,
        agent_id: "test-frontman"
      })

    row
  end

  defp history(task_id) do
    rows =
      task_id
      |> InteractionSchema.for_task()
      |> InteractionSchema.ordered()
      |> Repo.all()

    {:ok, history} = History.new(rows)
    history
  end
end
