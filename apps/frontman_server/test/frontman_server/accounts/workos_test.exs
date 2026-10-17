defmodule FrontmanServer.Accounts.WorkOSTest do
  use FrontmanServer.DataCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Workers.{NotifyDiscordNewUser, SendWelcomeEmail, SyncResendContact}

  setup do
    original = Application.fetch_env(:frontman_server, :workos_req_options)
    Application.put_env(:frontman_server, :workos_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      case original do
        {:ok, options} -> Application.put_env(:frontman_server, :workos_req_options, options)
        :error -> Application.delete_env(:frontman_server, :workos_req_options)
      end
    end)
  end

  for {function, arguments, grant} <- [
        {:authenticate_with_oauth, ["code", "nextjs"], "authorization_code"},
        {:authenticate_with_email_verification, ["code", "pending", "nextjs"],
         "urn:workos:oauth:grant-type:email-verification:code"}
      ] do
    @tag authentication: {function, arguments}, grant: grant
    test "#{function} creates once and links without signup jobs", context do
      {function, arguments} = context.authentication
      authenticate = fn -> apply(Accounts, function, arguments) end
      grant = %{"grant_type" => context.grant}

      stub_auth("GitHubOAuth", "github-id", grant)
      assert {:ok, user} = authenticate.()
      assert user.email == "signup@example.com"
      assert Repo.get!(User, user.id).confirmed_at

      assert [%{provider: "github", provider_id: "github-id"}] =
               Accounts.list_user_identities(user)

      assert_enqueued(worker: SendWelcomeEmail, args: %{user_id: user.id})
      assert_enqueued(worker: SyncResendContact, args: %{user_id: user.id})

      assert_enqueued(
        worker: NotifyDiscordNewUser,
        args: %{user_id: user.id, framework: "nextjs"}
      )

      assert length(all_enqueued()) == 3
      Repo.delete_all(Oban.Job)

      assert {:ok, %{id: id}} = authenticate.()
      assert id == user.id
      assert length(Accounts.list_user_identities(user)) == 1
      stub_auth("GoogleOAuth", "google-id", grant)
      assert {:ok, %{id: ^id}} = authenticate.()
      assert length(Accounts.list_user_identities(user)) == 2
      assert {:ok, _} = Accounts.unlink_oauth_provider(user, "google")
      stub_auth("GoogleOAuth", "explicit-id", %{"grant_type" => "authorization_code"})

      assert {:ok, %{user_id: ^id, provider_id: "explicit-id"}} =
               Accounts.link_oauth_provider(user, "code")

      assert Repo.aggregate(User, :count) == 1
      assert length(Accounts.list_user_identities(user)) == 2
      assert all_enqueued() == []
    end
  end

  defp stub_auth(method, provider_id, expected) do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/user_management/authenticate"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Map.take(Jason.decode!(body), Map.keys(expected)) == expected

      Req.Test.json(conn, %{
        authentication_method: method,
        user: %{id: provider_id, email: "signup@example.com"}
      })
    end)
  end
end
