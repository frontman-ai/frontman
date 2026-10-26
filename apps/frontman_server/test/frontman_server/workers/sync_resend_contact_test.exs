defmodule FrontmanServer.Workers.SyncResendContactTest do
  use FrontmanServer.DataCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Accounts, as: UserAccounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.ResendContacts
  alias FrontmanServer.Test.Fixtures.Accounts
  alias FrontmanServer.Workers.SyncResendContact

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    Sentry.Context.clear_all()
  end

  describe "perform/1" do
    for failure <- [500, :timeout, :exception] do
      @tag failure: failure, capture_log: true
      test "activation failure #{failure} retries five times and reports only exhaustion",
           %{failure: failure} do
        user = Accounts.user_fixture()
        assert UserAccounts.record_first_message(Scope.for_user(user))

        Req.Test.expect(:resend, 5, fn conn ->
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

        job = SyncResendContact.new(%{user_id: user.id, activation: true}) |> Oban.insert!()

        for attempt <- 1..5 do
          result = Oban.drain_queue(queue: :mailers, with_scheduled: true)
          stored = Repo.reload!(job)
          assert stored.attempt == attempt
          assert stored.errors != []
          error = List.last(stored.errors)["error"]
          assert error =~ %{500 => "500", timeout: "timeout", exception: "RuntimeError"}[failure]

          if attempt < 5 do
            assert result.failure == 1
            assert stored.state == "retryable"
            assert [] == Sentry.Test.pop_sentry_reports()
          else
            assert result.discard == 1
            assert stored.state == "discarded"
          end
        end

        assert [event] = Sentry.Test.pop_sentry_reports()
        category = %{500 => "http_error", timeout: "transport_uncertain", exception: "exception"}

        assert event.extra == %{
                 failure_category: category[failure],
                 status: if(failure == 500, do: 500),
                 user_id: user.id,
                 job_id: job.id
               }

        refute inspect(event) =~ user.email
        refute inspect(event) =~ "private-"
        refute inspect(event) =~ "re_test_key"
      end
    end

    test "activation sync is opt-in and stale signup jobs cannot write inactive" do
      now = ~U[2026-01-01 00:00:00Z]
      user = Accounts.user_fixture() |> Ecto.Changeset.change(inserted_at: now) |> Repo.update!()
      scope = Scope.for_user(user)
      entry = [enabled: false, contact_sync_enabled: true, cutoff: now, max_entry_lag_seconds: 60]

      assert :ok =
               ResendContacts.enter_activation_campaign(scope, entry, fn -> now end)

      assert :ok = ResendContacts.sync_contact(scope, :activation, enabled: true, cutoff: nil)
      assert :discard = perform_job(SyncResendContact, %{user_id: user.id, activation: true})
      assert UserAccounts.record_first_message(scope)

      Req.Test.expect(:resend, fn conn ->
        assert conn.method == "PATCH"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        properties = %{"frontman_activation_state" => "activated"}
        assert Jason.decode!(body) == %{"properties" => properties}

        Req.Test.json(conn, %{"id" => "abc-123"})
      end)

      Req.Test.expect(:resend, fn conn ->
        assert conn.method == "POST"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)
        assert payload["email"] == user.email
        assert Map.has_key?(payload, "first_name")
        assert payload["segments"] == [%{"id" => "5786d8bb-df16-413c-a06d-64d1a579cc2f"}]
        assert payload["properties"] == %{"frontman_activation_state" => "activated"}
        refute Map.has_key?(payload, "unsubscribed")
        refute Map.has_key?(payload, "topics")
        Req.Test.json(conn, %{"id" => "abc-123"})
      end)

      policy = [enabled: true, cutoff: now]
      assert :ok = ResendContacts.sync_contact(scope, :activation, policy)
      assert :ok = ResendContacts.sync_contact(scope, :signup, policy)
    end

    test "activation recovers a missing contact with activated properties" do
      user = Accounts.user_fixture()

      assert UserAccounts.record_first_message(Scope.for_user(user))

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
    end

    test "syncs contact details without subscription preferences, including repeated calls" do
      user = Accounts.user_fixture(%{name: "Steve Wozniak"})

      Req.Test.expect(:resend, 2, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["email"] == user.email
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer re_test_key"]
        assert payload["first_name"] == "Steve"
        refute Map.has_key?(payload, "unsubscribed")
        assert payload["segments"] == [%{"id" => "5786d8bb-df16-413c-a06d-64d1a579cc2f"}]

        Req.Test.json(conn, %{"object" => "contact", "id" => "abc-123"})
      end)

      assert :ok = perform_job(SyncResendContact, %{user_id: user.id})
      policy = [enabled: true, cutoff: nil]
      assert :ok = ResendContacts.sync_contact(Scope.for_user(user), :signup, policy)
    end

    test "returns error tuple on final generic failure without activation reporting" do
      user = Accounts.user_fixture()

      Req.Test.expect(:resend, fn conn ->
        conn |> Plug.Conn.put_status(422) |> Req.Test.json(%{"message" => "invalid"})
      end)

      assert {:error, _reason} =
               SyncResendContact.perform(%Oban.Job{
                 attempt: 5,
                 max_attempts: 5,
                 args: %{"user_id" => user.id}
               })

      assert [] == Sentry.Test.pop_sentry_reports()
    end

    test "discards the job when user does not exist" do
      assert :discard = perform_job(SyncResendContact, %{user_id: Ecto.UUID.generate()})
    end
  end
end
