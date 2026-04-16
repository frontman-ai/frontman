defmodule FrontmanServerWeb.OAuthControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers

  setup do
    Application.put_env(:workos, WorkOS.Client,
      api_key: "sk_test_workos",
      client_id: "client_test_workos"
    )

    Application.put_env(:frontman_server, :workos_req_options, plug: {Req.Test, :workos_auth})

    on_exit(fn ->
      Application.put_env(:workos, WorkOS.Client, api_key: nil, client_id: nil)
      Application.delete_env(:frontman_server, :workos_req_options)
    end)

    %{user: user_fixture()}
  end

  defp workos_auth_response(provider, opts) do
    user_id = Keyword.get(opts, :user_id, "user_#{System.unique_integer([:positive])}")
    email = Keyword.get(opts, :email, "test#{System.unique_integer([:positive])}@example.com")

    auth_method =
      case provider do
        "github" -> "GitHubOAuth"
        "google" -> "GoogleOAuth"
      end

    response = %{
      "user" => %{
        "id" => user_id,
        "email" => email,
        "email_verified" => true,
        "first_name" => "Test",
        "last_name" => "User",
        "profile_picture_url" => nil,
        "created_at" => DateTime.to_iso8601(DateTime.utc_now()),
        "updated_at" => DateTime.to_iso8601(DateTime.utc_now())
      },
      "access_token" => "wos_access_token",
      "refresh_token" => "wos_refresh_token",
      "authentication_method" => auth_method
    }

    case Keyword.get(opts, :oauth_tokens) do
      nil -> response
      tokens -> Map.put(response, "oauth_tokens", tokens)
    end
  end

  describe "GET /auth/callback - access_denied" do
    test "redirects with error message when user cancels", %{conn: conn} do
      conn = get(conn, ~p"/auth/callback", %{"error" => "access_denied"})

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Sign in was cancelled."
    end
  end

  describe "GET /auth/link/callback - access_denied" do
    test "redirects with error message when user cancels", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/auth/link/callback", %{"error" => "access_denied"})

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Connection was cancelled."
    end

    test "requires sudo mode", %{conn: conn, user: user} do
      old_auth_time = DateTime.add(DateTime.utc_now(), -30, :minute)

      conn =
        conn
        |> log_in_user(user, token_authenticated_at: old_auth_time)
        |> get(~p"/auth/link/callback", %{"error" => "access_denied"})

      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must re-authenticate to access this page."
    end
  end

  describe "DELETE /auth/:provider/unlink" do
    test "unlinks provider from user account", %{conn: conn, user: user} do
      _identity = identity_fixture(user, provider: "github")

      conn =
        conn
        |> log_in_user(user)
        |> delete(~p"/auth/github/unlink")

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "GitHub disconnected."
    end

    test "requires authentication", %{conn: conn} do
      conn = delete(conn, ~p"/auth/github/unlink")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "requires sudo mode", %{conn: conn, user: user} do
      _identity = identity_fixture(user, provider: "github")
      old_auth_time = DateTime.add(DateTime.utc_now(), -30, :minute)

      conn =
        conn
        |> log_in_user(user, token_authenticated_at: old_auth_time)
        |> delete(~p"/auth/github/unlink")

      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must re-authenticate to access this page."
    end
  end

  describe "GET /auth/callback - GitHub OAuth with tokens" do
    test "stores GitHub OAuth token on successful login", %{conn: conn} do
      github_tokens = %{
        "access_token" => "gho_github_access_123",
        "refresh_token" => "ghr_github_refresh_456",
        "expires_at" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 3600, :second)),
        "scopes" => ["repo", "read:user"]
      }

      response = workos_auth_response("github", oauth_tokens: github_tokens)

      Req.Test.stub(:workos_auth, fn conn ->
        Req.Test.json(conn, response)
      end)

      conn = get(conn, ~p"/auth/callback", %{"code" => "test_github_code"})

      assert redirected_to(conn) == ~p"/"

      # Verify the token was persisted.
      user =
        FrontmanServer.Repo.get_by!(FrontmanServer.Accounts.User,
          email: response["user"]["email"]
        )

      scope = Scope.for_user(user)
      token = Providers.get_oauth_token(scope, "github")

      assert token != nil
      assert token.access_token == "gho_github_access_123"
      assert token.refresh_token == "ghr_github_refresh_456"
    end
  end

  describe "GET /auth/callback - Google OAuth with tokens" do
    test "completes login without crashing when Google returns oauth_tokens", %{conn: conn} do
      google_tokens = %{
        "access_token" => "ya29_google_access_789",
        "refresh_token" => "ggl_google_refresh_012",
        "expires_at" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 3600, :second)),
        "scopes" => ["openid", "email", "profile"]
      }

      response = workos_auth_response("google", oauth_tokens: google_tokens)

      Req.Test.stub(:workos_auth, fn conn ->
        Req.Test.json(conn, response)
      end)

      conn = get(conn, ~p"/auth/callback", %{"code" => "test_google_code"})

      # Login must succeed — not crash with FunctionClauseError.
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Welcome!"
    end

    test "does not store Google tokens in the oauth_tokens table", %{conn: conn} do
      google_tokens = %{
        "access_token" => "ya29_google_access_789",
        "refresh_token" => "ggl_google_refresh_012",
        "expires_at" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 3600, :second)),
        "scopes" => ["openid", "email", "profile"]
      }

      response = workos_auth_response("google", oauth_tokens: google_tokens)

      Req.Test.stub(:workos_auth, fn conn ->
        Req.Test.json(conn, response)
      end)

      conn = get(conn, ~p"/auth/callback", %{"code" => "test_google_code"})

      assert redirected_to(conn) == ~p"/"

      user =
        FrontmanServer.Repo.get_by!(FrontmanServer.Accounts.User,
          email: response["user"]["email"]
        )

      scope = Scope.for_user(user)

      # Google tokens must NOT be stored as any provider.
      assert Providers.get_oauth_token(scope, "google") == nil
      assert Providers.get_oauth_token(scope, "github") == nil
    end
  end
end
