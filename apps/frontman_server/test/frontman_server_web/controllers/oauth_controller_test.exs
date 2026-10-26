defmodule FrontmanServerWeb.OAuthControllerTest do
  use FrontmanServerWeb.ConnCase, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.{User, UserIdentity}
  alias FrontmanServer.Repo

  alias FrontmanServer.Workers.{
    EnterActivationCampaign,
    NotifyDiscordNewUser,
    SendWelcomeEmail,
    SyncResendContact
  }

  setup do
    original = Application.fetch_env(:frontman_server, :workos_req_options)

    Application.put_env(:frontman_server, :workos_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    on_exit(fn ->
      case original do
        {:ok, options} -> Application.put_env(:frontman_server, :workos_req_options, options)
        :error -> Application.delete_env(:frontman_server, :workos_req_options)
      end
    end)
  end

  for {suffix, callback, key} <- [
        {"", "/auth/callback", :oauth_signin_state},
        {"/link", "/auth/link/callback", :oauth_state}
      ] do
    @tag suffix: suffix, callback: callback, key: key
    test "provider initiation #{suffix} validates providers and preserves state", context do
      conn =
        if context.suffix == "/link",
          do: log_in_user(context.conn, user_fixture()),
          else: context.conn

      for {provider, method} <- [{"google", "GoogleOAuth"}, {"github", "GitHubOAuth"}] do
        started = get(conn, "/auth/#{provider}#{context.suffix}")
        location = URI.parse(redirected_to(started))
        assert location.host == "api.workos.com"
        assert location.path == "/user_management/authorize"
        query = URI.decode_query(location.query)
        assert query["provider"] == method
        assert query["client_id"] == "client_test_workos"
        assert URI.parse(query["redirect_uri"]).path == context.callback
        assert query["state"] == get_session(started, context.key)
        assert byte_size(query["state"]) > 0
        invalid = get(started, "/auth/unsupported#{context.suffix}")
        assert response(invalid, 404) == "Not Found"
        assert get_resp_header(invalid, "location") == []
        assert get_session(invalid, context.key) == query["state"]
      end
    end
  end

  describe "successful authentication" do
    test "signup commits the account and jobs; repeat login does not enqueue again", %{conn: conn} do
      expect_auth(oauth_body(), 200, profile())
      conn = get(conn, ~p"/users/log-in?framework=nextjs")

      assert {:error, :rollback} =
               Repo.transact(fn ->
                 conn
                 |> sign_in()
                 |> assert_signed_in()
                 |> assert_signup()

                 {:error, :rollback}
               end)

      assert_no_signup(conn)
      expect_auth(oauth_body(), 200, profile())
      conn = conn |> get(~p"/users/log-in?framework=nextjs") |> sign_in()
      user = assert_signed_in(conn)
      assert_signup(user)

      Repo.delete_all(Oban.Job)
      observed_at = ~U[2026-06-02 12:00:00Z]
      user |> Ecto.Changeset.change(first_message_at: observed_at) |> Repo.update!()
      old_login = ~U[2020-01-01 00:00:00Z]
      identity = Repo.get_by!(UserIdentity, user_id: user.id)
      identity |> Ecto.Changeset.change(last_signed_in_at: old_login) |> Repo.update!()
      user |> Ecto.Changeset.change(last_signed_in_at: old_login) |> Repo.update!()

      expect_auth(oauth_body(), 200, profile())
      returned = build_conn() |> sign_in() |> assert_signed_in()
      assert returned.id == user.id
      assert returned.first_message_at == observed_at
      assert DateTime.compare(returned.last_signed_in_at, old_login) == :gt
      assert DateTime.compare(Repo.reload!(identity).last_signed_in_at, old_login) == :gt
      assert Repo.aggregate(User, :count) == 1
      assert Repo.aggregate(UserIdentity, :count) == 1
      assert all_enqueued() == []
    end

    test "email verification defers signup and preserves framework through completion", %{
      conn: conn
    } do
      expect_auth(oauth_body(), 400, %{
        code: "email_verification_required",
        pending_authentication_token: "pending",
        email: "signup@example.com"
      })

      conn = conn |> get(~p"/users/log-in?framework=nextjs") |> sign_in()
      assert redirected_to(conn) == ~p"/auth/verify-email"
      refute get_session(conn, :oauth_signin_state)
      assert get_session(conn, :pending_auth_token) == "pending"
      assert get_session(conn, :pending_auth_email) == "signup@example.com"
      assert_no_signup(conn)

      body = %{
        "grant_type" => "urn:workos:oauth:grant-type:email-verification:code",
        "code" => "123456",
        "pending_authentication_token" => "pending"
      }

      expect_auth(Map.put(body, "code", "wrong"), 400, %{code: "invalid_grant"})
      conn = post(conn, ~p"/auth/verify-email", %{"code" => "wrong"})
      assert redirected_to(conn) == ~p"/auth/verify-email"
      assert get_session(conn, :pending_auth_token) == "pending"
      assert_no_signup(conn)

      expect_auth(body, 200, profile())
      conn = post(conn, ~p"/auth/verify-email", %{"code" => "123456"})
      conn |> assert_signed_in() |> assert_signup()
      refute get_session(conn, :pending_auth_token)
      refute get_session(conn, :pending_auth_email)
    end

    test "same-email Google sign-in attaches the exact identity without signup jobs", %{
      conn: conn
    } do
      user = user_fixture(email: "signup@example.com")
      expect_auth(oauth_body(), 200, profile("GoogleOAuth", "google-id"))
      signed_in = conn |> sign_in("google") |> assert_signed_in()
      assert signed_in.id == user.id

      assert [%{provider: "google", provider_id: "google-id"}] =
               Accounts.list_user_identities(user)

      assert Repo.aggregate(User, :count) == 1
      assert all_enqueued() == []
    end

    test "known identity wins over a conflicting email match", %{conn: conn} do
      owner = user_fixture()
      other = user_fixture(email: "signup@example.com")
      identity_fixture(owner, provider: "github", provider_id: "github-id")
      expect_auth(oauth_body(), 200, profile())
      signed_in = conn |> sign_in() |> assert_signed_in()
      assert signed_in.id == owner.id
      assert Accounts.list_user_identities(other) == []
      assert Repo.aggregate(User, :count) == 2
      assert all_enqueued() == []
    end
  end

  describe "failed authentication" do
    for {label, status, response} <- [
          {"rejected code", 400, %{code: "invalid_grant", message: "Invalid code"}},
          {"malformed profile", 200, %{user: %{email: "signup@example.com"}}},
          {"invalid identity after user insertion", 200,
           %{authentication_method: "GitHubOAuth", user: %{id: " ", email: "signup@example.com"}}}
        ] do
      @tag status: status, response: response
      test "#{label} leaves no account, identity, jobs, or session", context do
        expect_auth(oauth_body(), context.status, context.response)
        started = get(context.conn, ~p"/auth/github")
        state = get_session(started, :oauth_signin_state)
        conn = get(started, ~p"/auth/callback", %{"code" => "code", "state" => state})
        assert redirected_to(conn) == ~p"/users/log-in"
        assert Phoenix.Flash.get(conn.assigns.flash, :error)
        assert_no_signup(conn)
        refute get_session(conn, :oauth_signin_state)
        replay = get(conn, ~p"/auth/callback", %{"code" => "code", "state" => state})
        assert redirected_to(replay) == ~p"/users/log-in"
        assert_no_signup(replay)
      end
    end

    @tag :capture_log
    test "transport timeout leaves no account, identity, jobs, or session", %{conn: conn} do
      Req.Test.expect(__MODULE__, &Req.Test.transport_error(&1, :timeout))
      conn = sign_in(conn)
      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :oauth_signin_state)
      assert_no_signup(conn)
    end

    test "verification without a pending token never contacts WorkOS", %{conn: conn} do
      conn = post(conn, ~p"/auth/verify-email", %{"code" => "123456"})
      assert redirected_to(conn) == ~p"/users/log-in"
      assert_no_signup(conn)
    end
  end

  describe "GET /auth/callback - access_denied" do
    test "redirects with error message when user cancels", %{conn: conn} do
      conn = get(conn, ~p"/auth/github")
      state = get_session(conn, :oauth_signin_state)
      conn = get(conn, ~p"/auth/callback", %{"error" => "access_denied", "state" => state})

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Sign in was cancelled."
      refute get_session(conn, :oauth_signin_state)
    end
  end

  describe "GET /auth/link/callback" do
    setup :register_and_log_in_user

    test "links a provider using the saved state without signup jobs", %{conn: conn, user: user} do
      conn = get(conn, ~p"/auth/google/link")
      state = get_session(conn, :oauth_state)
      assert is_binary(state)
      assert URI.decode_query(URI.parse(redirected_to(conn)).query)["state"] == state
      expect_auth(oauth_body(), 200, profile("GoogleOAuth", "google-id"))
      conn = get(conn, ~p"/auth/link/callback", %{"code" => "code", "state" => state})
      assert redirected_to(conn) == ~p"/users/settings"
      refute get_session(conn, :oauth_state)

      assert [%{provider: "google", provider_id: "google-id"}] =
               Accounts.list_user_identities(user)

      assert Repo.aggregate(User, :count) == 1
      assert all_enqueued() == []
    end

    test "mismatched state cannot link an identity", %{conn: conn} do
      conn = get(conn, ~p"/auth/google/link")
      state = get_session(conn, :oauth_state)
      conn = get(conn, ~p"/auth/link/callback", %{"code" => "code", "state" => "wrong"})
      assert redirected_to(conn) == ~p"/users/settings"
      assert get_session(conn, :oauth_state) == state

      assert Repo.aggregate(UserIdentity, :count) == 0
      assert all_enqueued() == []
    end

    test "redirects with error message when user cancels", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(~p"/auth/google/link")
      state = get_session(conn, :oauth_state)
      conn = get(conn, ~p"/auth/link/callback", %{"error" => "access_denied", "state" => state})

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Connection was cancelled."
      refute get_session(conn, :oauth_state)
    end
  end

  describe "DELETE /auth/:provider/unlink" do
    setup do
      %{user: user_fixture()}
    end

    test "unlinks provider from user account", %{conn: conn, user: user} do
      _identity = identity_fixture(user, provider: "github")

      conn =
        conn
        |> log_in_user(user)
        |> delete(~p"/auth/github/unlink")

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "GitHub disconnected."

      for provider <- ["github", "google", "unsupported"] do
        assert conn |> delete("/auth/#{provider}/unlink") |> response(404) == "Not Found"
      end
    end
  end

  test "linking and unlinking retain authentication and sudo gates", %{conn: conn} do
    user = user_fixture()
    identity_fixture(user, provider: "github")

    for {method, path} <- [
          {:get, "/auth/unsupported/link"},
          {:get, "/auth/link/callback?error=access_denied"},
          {:delete, "/auth/github/unlink"},
          {:delete, "/auth/unsupported/unlink"}
        ] do
      assert conn |> dispatch(@endpoint, method, path) |> redirected_to() == ~p"/users/log-in"

      stale =
        log_in_user(conn, user,
          token_authenticated_at: DateTime.add(DateTime.utc_now(), -30, :minute)
        )

      denied = dispatch(stale, @endpoint, method, path)
      assert redirected_to(denied) == ~p"/users/log-in"

      assert Phoenix.Flash.get(denied.assigns.flash, :error) ==
               "You must re-authenticate to access this page."
    end
  end

  test "invalid sign-in state never reaches WorkOS or mutates accounts", %{conn: conn} do
    conn = get(conn, ~p"/auth/github")
    state = get_session(conn, :oauth_signin_state)

    for invalid <- [nil, "", "wrong", ["malformed"]] do
      rejected = get(conn, ~p"/auth/callback", %{"code" => "code", "state" => invalid})
      assert redirected_to(rejected) == ~p"/users/log-in"
      assert get_session(rejected, :oauth_signin_state) == state
      assert_no_signup(rejected)
    end
  end

  test "rejected linking exchanges consume state without identity mutation or jobs", %{conn: conn} do
    user = user_fixture()
    identity_fixture(user, provider: "github", provider_id: "github-id")
    identities = Accounts.list_user_identities(user)

    for {status, body} <- [
          {400, %{code: "invalid_grant", message: "untrusted"}},
          {200, profile()},
          {200, %{}},
          {200, profile("UnknownOAuth")}
        ] do
      started = conn |> log_in_user(user) |> get(~p"/auth/github/link")
      state = get_session(started, :oauth_state)
      expect_auth(oauth_body(), status, body)
      failed = get(started, ~p"/auth/link/callback", %{"code" => "code", "state" => state})
      assert redirected_to(failed) == ~p"/users/settings"

      assert Phoenix.Flash.get(failed.assigns.flash, :error) ==
               "Connection failed. Please try again."

      refute get_session(failed, :oauth_state)
      assert Accounts.list_user_identities(user) == identities
      assert Repo.aggregate(User, :count) == 1
      assert all_enqueued() == []
    end
  end

  defp sign_in(conn, provider \\ "github") do
    conn = get(conn, "/auth/#{provider}")
    state = get_session(conn, :oauth_signin_state)
    get(conn, ~p"/auth/callback", %{"code" => "code", "state" => state})
  end

  defp oauth_body, do: %{"grant_type" => "authorization_code", "code" => "code"}

  defp profile(method \\ "GitHubOAuth", id \\ "github-id") do
    %{authentication_method: method, user: %{id: id, email: "signup@example.com"}}
  end

  defp expect_auth(body, status, response) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.host == "api.workos.com"
      assert conn.request_path == "/user_management/authenticate"
      {:ok, json, conn} = read_body(conn)

      assert Jason.decode!(json) ==
               Map.merge(body, %{
                 "client_id" => "client_test_workos",
                 "client_secret" => "sk_test_workos"
               })

      conn |> put_status(status) |> Req.Test.json(response)
    end)
  end

  defp assert_signed_in(conn) do
    assert redirected_to(conn) == ~p"/"
    assert {user, _} = Accounts.get_user_by_session_token(get_session(conn, :user_token))
    assert conn.resp_cookies["_frontman_server_web_user_remember_me"]
    Repo.reload!(user)
  end

  defp assert_signup(user) do
    assert user.email == "signup@example.com"
    assert user.confirmed_at
    assert is_nil(user.first_message_at)
    assert Repo.aggregate(User, :count) == 1
    assert [%{provider: "github", provider_id: "github-id"}] = Accounts.list_user_identities(user)
    assert_enqueued(worker: SendWelcomeEmail, args: %{user_id: user.id})
    assert_enqueued(worker: SyncResendContact, args: %{user_id: user.id})
    assert_enqueued(worker: EnterActivationCampaign, args: %{user_id: user.id})
    assert_enqueued(worker: NotifyDiscordNewUser, args: %{user_id: user.id, framework: "nextjs"})
    assert length(all_enqueued()) == 4
  end

  defp assert_no_signup(conn) do
    refute get_session(conn, :user_token)
    assert Repo.aggregate(User, :count) == 0
    assert Repo.aggregate(UserIdentity, :count) == 0
    assert all_enqueued() == []
  end
end
