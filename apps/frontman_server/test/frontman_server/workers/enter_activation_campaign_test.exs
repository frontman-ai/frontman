defmodule FrontmanServer.Workers.EnterActivationCampaignTest do
  use FrontmanServer.DataCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Test.Fixtures.Accounts, as: Fixtures
  alias FrontmanServer.Workers.{EnterActivationCampaign, SyncResendContact}

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    Sentry.Context.clear_all()

    for {module, options} <- [
          {EnterActivationCampaign, [enabled: true]},
          {SyncResendContact, [enabled: true]},
          {FrontmanServer.ResendClient,
           [req_options: [plug: {Req.Test, __MODULE__}, retry: true]]}
        ] do
      original = Application.get_env(:frontman_server, module, [])
      Application.put_env(:frontman_server, module, Keyword.merge(original, options))
      on_exit(fn -> Application.put_env(:frontman_server, module, original) end)
    end

    Application.put_env(
      :frontman_server,
      EnterActivationCampaign,
      Application.get_env(:frontman_server, EnterActivationCampaign)
      |> Keyword.merge(cutoff: DateTime.add(DateTime.utc_now(), -60), max_entry_lag_seconds: 60)
    )

    %{user: Fixtures.user_fixture()}
  end

  test "initializes current contact then submits exactly one event", %{user: user} do
    assert EnterActivationCampaign.new(%{user_id: user.id}).changes.max_attempts == 1

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "properties" => %{
                 "frontman_activation_state" => "inactive"
               }
             }

      Req.Test.json(conn, %{"id" => "contact"})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
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

  for failure <- [422, 500, :timeout, :exception] do
    @tag failure: failure
    test "entry failure #{failure} is reported without retry or private data", %{
      user: user,
      failure: failure
    } do
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, %{"id" => "contact"}))

      Req.Test.expect(__MODULE__, fn conn ->
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

  test "uncertain initialization never emits entry; Accounts enqueues activation exit", %{
    user: user
  } do
    Req.Test.expect(__MODULE__, fn conn ->
      assert :ok = Accounts.record_first_message(Scope.for_user(user))
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:discard, _} = perform_job(EnterActivationCampaign, %{user_id: user.id})
    assert_enqueued(worker: SyncResendContact, args: %{user_id: user.id, activation: true})
    assert [event] = Sentry.Test.pop_sentry_reports()
    assert event.extra.failure_category == "transport_uncertain"
  end

  test "activation during successful initialization prevents entry", %{user: user} do
    Req.Test.expect(__MODULE__, fn conn ->
      assert :ok = Accounts.record_first_message(Scope.for_user(user))
      Req.Test.json(conn, %{"id" => "contact"})
    end)

    assert :ok = perform_job(EnterActivationCampaign, %{user_id: user.id})
    assert_enqueued(worker: SyncResendContact, args: %{user_id: user.id, activation: true})
  end

  test "disabled, old, unconfirmed, activated, and late users make no requests", %{user: user} do
    config = Application.get_env(:frontman_server, EnterActivationCampaign)

    Application.put_env(
      :frontman_server,
      EnterActivationCampaign,
      Keyword.put(config, :enabled, false)
    )

    assert :ok = perform_job(EnterActivationCampaign, %{user_id: user.id})
    assert {:ok, :excluded} = EnterActivationCampaign.enqueue_signup(user)
    Application.put_env(:frontman_server, EnterActivationCampaign, config)

    for changes <- [
          [inserted_at: DateTime.add(DateTime.utc_now(:second), -120)],
          [confirmed_at: nil],
          [first_message_at: DateTime.utc_now(:second)]
        ] do
      baseline = [
        inserted_at: user.inserted_at,
        confirmed_at: user.confirmed_at,
        first_message_at: nil
      ]

      user |> Ecto.Changeset.change(Keyword.merge(baseline, changes)) |> Repo.update!()
      assert :ok = perform_job(EnterActivationCampaign, %{user_id: user.id})
    end

    Application.put_env(
      :frontman_server,
      EnterActivationCampaign,
      Keyword.merge(config, cutoff: DateTime.add(DateTime.utc_now(), -3600))
    )

    user
    |> Ecto.Changeset.change(
      inserted_at: DateTime.add(DateTime.utc_now(:second), -120),
      confirmed_at: user.confirmed_at,
      first_message_at: nil
    )
    |> Repo.update!()

    assert :ok = perform_job(EnterActivationCampaign, %{user_id: user.id})
  end

  test "entry refuses a disabled contact integration", %{user: user} do
    original = Application.get_env(:frontman_server, SyncResendContact)

    Application.put_env(
      :frontman_server,
      SyncResendContact,
      Keyword.put(original, :enabled, false)
    )

    assert {:ok, :excluded} = EnterActivationCampaign.enqueue_signup(user)
    assert :ok = perform_job(EnterActivationCampaign, %{user_id: user.id})
  end

  test "entry requires a UTC cutoff and positive lag in campaign config", %{user: user} do
    original = Application.get_env(:frontman_server, EnterActivationCampaign)

    for invalid <- [[cutoff: nil], [cutoff: "not-a-DateTime"], [max_entry_lag_seconds: 0]] do
      Application.put_env(
        :frontman_server,
        EnterActivationCampaign,
        Keyword.merge(original, invalid)
      )

      assert {:ok, :excluded} = EnterActivationCampaign.enqueue_signup(user)
      assert :ok = perform_job(EnterActivationCampaign, %{user_id: user.id})
    end
  end

  test "manual retry refuses a second attempt and reports replay category", %{user: user} do
    assert {:discard, :entry_replay_refused} =
             EnterActivationCampaign.perform(%Oban.Job{
               id: 123,
               attempt: 2,
               args: %{"user_id" => user.id}
             })

    assert [event] = Sentry.Test.pop_sentry_reports()
    assert event.extra.failure_category == "replay_refused"
  end

  test "new OAuth signup enqueues entry atomically but repeat login does not" do
    original = Application.get_env(:frontman_server, :workos_req_options, [])

    Application.put_env(:frontman_server, :workos_req_options,
      plug: {Req.Test, :activation_signup}
    )

    on_exit(fn -> Application.put_env(:frontman_server, :workos_req_options, original) end)

    Req.Test.stub(:activation_signup, fn conn ->
      Req.Test.json(conn, %{
        authentication_method: "GitHubOAuth",
        user: %{id: "activation-oauth", email: "activation@example.test"}
      })
    end)

    assert {:error, :rollback} =
             Repo.transact(fn ->
               assert {:ok, user} = Accounts.authenticate_with_oauth("code")
               assert_enqueued(worker: EnterActivationCampaign, args: %{user_id: user.id})
               {:error, :rollback}
             end)

    refute_enqueued(worker: EnterActivationCampaign)
    assert Accounts.get_user_by_email("activation@example.test") == nil

    assert {:ok, user} = Accounts.authenticate_with_oauth("code")
    assert {:ok, returned} = Accounts.authenticate_with_oauth("code")
    assert returned.id == user.id
    assert [_job] = all_enqueued(worker: EnterActivationCampaign)
  end
end
