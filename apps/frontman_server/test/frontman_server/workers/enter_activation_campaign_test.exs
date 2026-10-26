defmodule FrontmanServer.Workers.EnterActivationCampaignTest do
  use FrontmanServer.DataCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Test.Fixtures.Accounts, as: Fixtures
  alias FrontmanServer.Workers.{EnterActivationCampaign, SyncResendContact}

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    Sentry.Context.clear_all()
    %{user: Fixtures.user_fixture()}
  end

  test "initializes current contact then submits exactly one event", %{user: user} do
    assert EnterActivationCampaign.new(%{user_id: user.id}).changes.max_attempts == 1

    Req.Test.expect(:resend, fn conn ->
      assert conn.method == "PATCH"
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "properties" => %{
                 "frontman_activation_state" => "inactive"
               }
             }

      Req.Test.json(conn, %{"id" => "contact"})
    end)

    Req.Test.expect(:resend, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/events/send"
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "event" => "frontman.activation.entered",
               "email" => user.email
             }

      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer re_test_key"]
      conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{"object" => "event"})
    end)

    assert :ok = perform_job(EnterActivationCampaign, %{user_id: user.id})
    assert [] == Sentry.Test.pop_sentry_reports()
  end

  for failure <- [500, :timeout, :exception] do
    @tag failure: failure
    test "entry failure #{failure} is reported without retry or private data", %{
      user: user,
      failure: failure
    } do
      Req.Test.expect(:resend, &Req.Test.json(&1, %{"id" => "contact"}))

      Req.Test.expect(:resend, fn conn ->
        case failure do
          status when is_integer(status) -> Plug.Conn.send_resp(conn, status, user.email)
          :timeout -> Req.Test.transport_error(conn, :timeout)
          :exception -> raise "private #{user.email}"
        end
      end)

      Sentry.Context.set_user_context(%{email: user.email})
      Sentry.Context.set_extra_context(%{token: "private-token"})
      assert {:discard, _} = perform_job(EnterActivationCampaign, %{user_id: user.id})
      assert [event] = Sentry.Test.pop_sentry_reports()
      assert event.extra.user_id == user.id

      expected_category =
        case failure do
          status when is_integer(status) -> "http_error"
          :timeout -> "transport_uncertain"
          :exception -> "exception"
        end

      assert event.extra.failure_category == expected_category
      refute inspect(event) =~ user.email
      refute inspect(event) =~ "private-token"
    end
  end

  test "uncertain initialization never emits entry; prompt acceptance enqueues exit", %{
    user: user
  } do
    Req.Test.expect(:resend, fn conn ->
      accept_prompt(user)
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:discard, _} = perform_job(EnterActivationCampaign, %{user_id: user.id})
    assert_enqueued(worker: SyncResendContact, args: %{user_id: user.id, activation: true})
    assert [event] = Sentry.Test.pop_sentry_reports()
    assert event.extra.failure_category == "transport_uncertain"
  end

  test "activation during successful initialization prevents entry", %{user: user} do
    Req.Test.expect(:resend, fn conn ->
      accept_prompt(user)
      Req.Test.json(conn, %{"id" => "contact"})
    end)

    assert :ok = perform_job(EnterActivationCampaign, %{user_id: user.id})
    assert_enqueued(worker: SyncResendContact, args: %{user_id: user.id, activation: true})
  end

  test "rollout and eligibility guards make no requests" do
    now = ~U[2026-01-01 00:01:00Z]

    policy = [
      enabled: true,
      contact_sync_enabled: true,
      cutoff: ~U[2026-01-01 00:00:00Z],
      max_entry_lag_seconds: 60
    ]

    for {overrides, changes} <- [
          {[enabled: false], []},
          {[contact_sync_enabled: false], []},
          {[cutoff: nil], []},
          {[max_entry_lag_seconds: 0], []},
          {[], [inserted_at: ~U[2025-12-31 23:59:59Z]]},
          {[cutoff: ~U[2025-01-01 00:00:00Z]], [inserted_at: ~U[2025-12-31 23:59:59Z]]},
          {[], [confirmed_at: nil]},
          {[], [first_message_at: now]}
        ] do
      user = Fixtures.user_fixture()

      user =
        user
        |> Ecto.Changeset.change(Keyword.merge([inserted_at: now], changes))
        |> Repo.update!()

      assert :ok =
               FrontmanServer.ResendContacts.enter_activation_campaign(
                 Scope.for_user(user),
                 Keyword.merge(policy, overrides),
                 fn -> now end
               )
    end
  end

  test "request-spanning expiry rechecks time without changing the user" do
    now = ~U[2026-01-01 00:00:00Z]
    user = Fixtures.user_fixture() |> Ecto.Changeset.change(inserted_at: now) |> Repo.update!()
    clock = start_supervised!({Agent, fn -> [now, DateTime.add(now, 61)] end})
    Req.Test.expect(:resend, &Req.Test.json(&1, %{"id" => "contact"}))

    assert :ok =
             FrontmanServer.ResendContacts.enter_activation_campaign(
               Scope.for_user(user),
               [
                 enabled: true,
                 contact_sync_enabled: true,
                 cutoff: now,
                 max_entry_lag_seconds: 60
               ],
               fn -> Agent.get_and_update(clock, fn [time | rest] -> {time, rest} end, 1000) end
             )

    assert Repo.reload!(user).inserted_at == now
  end

  test "manual retry refuses a second attempt and reports replay category", %{user: user} do
    Req.Test.expect(:resend, &Req.Test.json(&1, %{"id" => "contact"}))
    Req.Test.expect(:resend, &Req.Test.transport_error(&1, :timeout))
    job = EnterActivationCampaign.new(%{user_id: user.id}) |> Oban.insert!()
    assert %{discard: 1} = Oban.drain_queue(queue: :mailers)
    assert Repo.reload!(job).state == "discarded"
    assert [_] = Sentry.Test.pop_sentry_reports()

    assert :ok = Oban.retry_job(job.id)
    assert %{discard: 1} = Oban.drain_queue(queue: :mailers)
    assert Repo.reload!(job).attempt == 2

    assert [event] = Sentry.Test.pop_sentry_reports()
    assert event.extra.failure_category == "replay_refused"
  end

  defp accept_prompt(user) do
    scope = Scope.for_user(user)
    FrontmanServer.BillingFixtures.allow_access_for_scope_fixture(scope)
    task = FrontmanServer.Test.Fixtures.Tasks.task_fixture(scope)

    assert {:ok, _} =
             Tasks.submit_user_message(scope, %{
               task_id: task.id,
               message_id: Ecto.UUID.generate(),
               message: [%{"type" => "text", "text" => "hello"}],
               model: "openrouter:openai/gpt-5.5",
               agent_id: "test-frontman"
             })
  end
end
