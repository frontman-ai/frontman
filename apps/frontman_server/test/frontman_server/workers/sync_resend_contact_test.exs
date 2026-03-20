defmodule FrontmanServer.Workers.SyncResendContactTest do
  use FrontmanServer.DataCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.AccountsFixtures
  alias FrontmanServer.Workers.SyncResendContact

  # Inject Req.Test as the HTTP adapter so no real network calls are made.
  # The Resend API key comes from test.exs ("re_test_key") — no patching needed.
  setup do
    Application.put_env(:frontman_server, :sync_resend_contact_req_options,
      plug: {Req.Test, :resend}
    )

    on_exit(fn ->
      Application.delete_env(:frontman_server, :sync_resend_contact_req_options)
    end)

    :ok
  end

  describe "perform/1" do
    test "syncs the user to Resend Contacts on success" do
      user = AccountsFixtures.user_fixture(%{name: "Steve Wozniak"})

      Req.Test.stub(:resend, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["email"] == user.email
        assert payload["first_name"] == "Steve"
        assert payload["unsubscribed"] == false
        assert payload["segments"] == [%{"id" => "974ede17-1b25-4e48-a71d-6d5f0923f402"}]

        Req.Test.json(conn, %{"object" => "contact", "id" => "abc-123"})
      end)

      assert :ok = perform_job(SyncResendContact, %{user_id: user.id})
    end

    test "sends the correct Authorization header" do
      user = AccountsFixtures.user_fixture()

      Req.Test.stub(:resend, fn conn ->
        auth = Plug.Conn.get_req_header(conn, "authorization")
        assert auth == ["Bearer re_test_key"]
        Req.Test.json(conn, %{"object" => "contact", "id" => "abc-123"})
      end)

      assert :ok = perform_job(SyncResendContact, %{user_id: user.id})
    end

    test "extracts first name from full name" do
      user = AccountsFixtures.user_fixture(%{name: "Ada Lovelace"})

      Req.Test.stub(:resend, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["first_name"] == "Ada"
        Req.Test.json(conn, %{"object" => "contact", "id" => "abc-123"})
      end)

      assert :ok = perform_job(SyncResendContact, %{user_id: user.id})
    end

    test "returns error tuple on non-2xx response" do
      user = AccountsFixtures.user_fixture()

      Req.Test.stub(:resend, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(422, Jason.encode!(%{"message" => "invalid"}))
      end)

      assert {:error, _reason} = perform_job(SyncResendContact, %{user_id: user.id})
    end

    test "discards the job when user does not exist" do
      non_existent_id = Ecto.UUID.generate()

      # No Req stub needed — the worker never reaches the HTTP call.
      assert :discard = perform_job(SyncResendContact, %{user_id: non_existent_id})
    end

    test "enqueues with correct queue" do
      user = AccountsFixtures.user_fixture()
      changeset = SyncResendContact.new(%{user_id: user.id})

      assert changeset.changes.queue == "mailers"
    end
  end
end
