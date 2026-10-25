defmodule FrontmanServer.Workers.SyncResendContactTest do
  use FrontmanServer.DataCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Accounts, as: UserAccounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Test.Fixtures.Accounts
  alias FrontmanServer.Workers.EnterActivationCampaign
  alias FrontmanServer.Workers.SyncResendContact

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    Sentry.Context.clear_all()

    original_campaign = Application.get_env(:frontman_server, EnterActivationCampaign, [])

    on_exit(fn ->
      Application.put_env(:frontman_server, EnterActivationCampaign, original_campaign)
    end)

    original_config = Application.get_env(:frontman_server, SyncResendContact, [])

    Application.put_env(
      :frontman_server,
      SyncResendContact,
      Keyword.put(original_config, :req_options, plug: {Req.Test, :resend}, retry: false)
    )

    on_exit(fn ->
      Application.put_env(:frontman_server, SyncResendContact, original_config)
    end)

    :ok
  end

  describe "perform/1" do
    for failure <- [422, 500, :timeout, :exception],
        attempt <- [4, 5, 6] do
      @tag failure: failure, attempt: attempt
      test "activation failure #{failure} at attempt #{attempt} retains retries and reports only final failures",
           %{failure: failure, attempt: attempt} do
        user = Accounts.user_fixture()
        config = Application.get_env(:frontman_server, EnterActivationCampaign)

        Application.put_env(
          :frontman_server,
          EnterActivationCampaign,
          Keyword.merge(config, enabled: false, cutoff: ~U[2026-01-01 00:00:00Z])
        )

        :ok = UserAccounts.record_first_message(Scope.for_user(user))

        Req.Test.expect(:resend, fn conn ->
          case failure do
            status when is_integer(status) ->
              Plug.Conn.send_resp(conn, status, "private-body #{user.email}")

            :timeout ->
              Req.Test.transport_error(conn, :timeout)

            :exception ->
              raise "private-exception #{user.email}"
          end
        end)

        Sentry.Context.set_user_context(%{email: user.email})
        Sentry.Context.set_extra_context(%{token: "private-token"})

        job = %Oban.Job{
          id: 123,
          attempt: attempt,
          max_attempts: 5,
          args: %{"user_id" => user.id, "activation" => true}
        }

        case failure do
          :exception ->
            assert_raise RuntimeError, fn -> SyncResendContact.perform(job) end

          _ ->
            assert {:error, _} = SyncResendContact.perform(job)
        end

        if attempt >= job.max_attempts do
          assert [event] = Sentry.Test.pop_sentry_reports()

          {category, status} =
            case failure do
              status when is_integer(status) -> {"http_error", status}
              :timeout -> {"transport_uncertain", nil}
              :exception -> {"exception", nil}
            end

          assert event.extra == %{
                   failure_category: category,
                   status: status,
                   user_id: user.id,
                   job_id: 123
                 }

          refute inspect(event) =~ user.email
          refute inspect(event) =~ "private-"
          refute inspect(event) =~ "re_test_key"
        else
          assert [] == Sentry.Test.pop_sentry_reports()
        end
      end
    end

    test "activation sync is opt-in and stale signup jobs cannot write inactive" do
      user = Accounts.user_fixture()
      assert :ok = perform_job(SyncResendContact, %{user_id: user.id, activation: true})

      config = Application.get_env(:frontman_server, EnterActivationCampaign)

      Application.put_env(
        :frontman_server,
        EnterActivationCampaign,
        Keyword.merge(config, enabled: false, cutoff: ~U[2026-01-01 00:00:00Z])
      )

      assert :ok =
               UserAccounts.record_first_message(Scope.for_user(user))

      Req.Test.expect(:resend, 2, fn conn ->
        assert conn.method == "PATCH"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)
        assert payload["properties"] == %{"frontman_activation_state" => "activated"}
        refute Map.has_key?(payload, "unsubscribed")
        refute Map.has_key?(payload, "topics")
        Req.Test.json(conn, %{"id" => "abc-123"})
      end)

      assert :ok = perform_job(SyncResendContact, %{user_id: user.id, activation: true})
      assert :ok = perform_job(SyncResendContact, %{user_id: user.id})
    end

    test "activation recovers a missing contact and retries provider failures" do
      user = Accounts.user_fixture()
      config = Application.get_env(:frontman_server, EnterActivationCampaign)

      Application.put_env(
        :frontman_server,
        EnterActivationCampaign,
        Keyword.merge(config, enabled: false, cutoff: ~U[2026-01-01 00:00:00Z])
      )

      assert :ok =
               UserAccounts.record_first_message(Scope.for_user(user))

      Req.Test.expect(:resend, fn conn ->
        assert conn.method == "PATCH"
        Plug.Conn.send_resp(conn, 404, "")
      end)

      Req.Test.expect(:resend, fn conn ->
        assert conn.method == "POST"
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert Jason.decode!(body)["properties"] ==
                 %{"frontman_activation_state" => "activated"}

        Req.Test.json(conn, %{"id" => "abc-123"})
      end)

      assert :ok = perform_job(SyncResendContact, %{user_id: user.id, activation: true})

      Req.Test.expect(:resend, &Req.Test.transport_error(&1, :timeout))

      assert {:error, %Req.TransportError{reason: :timeout}} =
               perform_job(SyncResendContact, %{user_id: user.id, activation: true})

      Req.Test.expect(:resend, &Req.Test.json(&1, %{"id" => "abc-123"}))
      assert :ok = perform_job(SyncResendContact, %{user_id: user.id, activation: true})
    end

    test "syncs contact details without subscription preferences, including repeated calls" do
      user = Accounts.user_fixture(%{name: "Steve Wozniak"})

      Req.Test.stub(:resend, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["email"] == user.email
        assert payload["first_name"] == "Steve"
        refute Map.has_key?(payload, "unsubscribed")
        assert payload["segments"] == [%{"id" => "5786d8bb-df16-413c-a06d-64d1a579cc2f"}]

        Req.Test.json(conn, %{"object" => "contact", "id" => "abc-123"})
      end)

      assert :ok = perform_job(SyncResendContact, %{user_id: user.id})
      assert :ok = perform_job(SyncResendContact, %{user_id: user.id})
    end

    test "sends the correct Authorization header" do
      user = Accounts.user_fixture()

      Req.Test.stub(:resend, fn conn ->
        auth = Plug.Conn.get_req_header(conn, "authorization")
        assert auth == ["Bearer re_test_key"]
        Req.Test.json(conn, %{"object" => "contact", "id" => "abc-123"})
      end)

      assert :ok = perform_job(SyncResendContact, %{user_id: user.id})
    end

    test "extracts first name from full name" do
      user = Accounts.user_fixture(%{name: "Ada Lovelace"})

      Req.Test.stub(:resend, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["first_name"] == "Ada"
        Req.Test.json(conn, %{"object" => "contact", "id" => "abc-123"})
      end)

      assert :ok = perform_job(SyncResendContact, %{user_id: user.id})
    end

    test "returns error tuple on non-2xx response" do
      user = Accounts.user_fixture()

      Req.Test.stub(:resend, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(422, Jason.encode!(%{"message" => "invalid"}))
      end)

      assert {:error, _reason} = perform_job(SyncResendContact, %{user_id: user.id})
    end

    test "returns transport errors" do
      user = Accounts.user_fixture()
      Req.Test.expect(:resend, &Req.Test.transport_error(&1, :timeout))

      assert {:error, %Req.TransportError{reason: :timeout}} =
               perform_job(SyncResendContact, %{user_id: user.id})
    end

    test "discards the job when user does not exist" do
      non_existent_id = Ecto.UUID.generate()

      assert :discard = perform_job(SyncResendContact, %{user_id: non_existent_id})
    end

    test "enqueues with correct queue" do
      user = Accounts.user_fixture()
      changeset = SyncResendContact.new(%{user_id: user.id})

      assert changeset.changes.queue == "mailers"
    end
  end
end
