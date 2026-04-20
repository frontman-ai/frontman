defmodule FrontmanServerWeb.UserSessionControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  alias FrontmanServer.Accounts

  setup do
    %{unconfirmed_user: unconfirmed_user_fixture(), user: user_fixture()}
  end

  describe "GET /users/log-in" do
    test "renders login page with OAuth options", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in")
      response = html_response(conn, 200)
      assert response =~ "Sign in to Frontman"
      # OAuth-only login now - shows GitHub and Google options
      assert response =~ "Continue with GitHub"
      assert response =~ "Continue with Google"
    end

    test "stores canonical signup framework in session", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in?#{%{"framework" => "nextjs"}}")

      assert get_session(conn, :signup_framework) == "nextjs"
    end

    test "rejects non-canonical signup framework labels", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{signup_framework: "nextjs"})
        |> get(~p"/users/log-in?#{%{"framework" => "Next.js"}}")

      refute get_session(conn, :signup_framework)
    end

    test "clears signup framework when value is invalid", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{signup_framework: "nextjs"})
        |> get(~p"/users/log-in?#{%{"framework" => "totally-unknown"}}")

      refute get_session(conn, :signup_framework)
    end

    test "clears signup framework when param is missing", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{signup_framework: "nextjs"})
        |> get(~p"/users/log-in")

      refute get_session(conn, :signup_framework)
    end

    test "redirects to home when already logged in", %{conn: conn, user: user} do
      # The login route has redirect_if_user_is_authenticated plug,
      # so authenticated users are redirected away from the login page
      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/users/log-in")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "GET /users/log-in/:token" do
    test "renders confirmation page for unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/log-in/#{token}")
      assert html_response(conn, 200) =~ "Confirm and stay logged in"
    end

    test "renders login page for confirmed user", %{conn: conn, user: user} do
      token =
        extract_user_token(fn url ->
          Accounts.deliver_login_instructions(user, url)
        end)

      conn = get(conn, ~p"/users/log-in/#{token}")
      html = html_response(conn, 200)
      refute html =~ "Confirm my account"
      assert html =~ "Keep me logged in on this device"
    end

    test "raises error for invalid token", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in/invalid-token")
      assert redirected_to(conn) == ~p"/users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Magic link is invalid or it has expired."
    end
  end

  describe "POST /users/log-in - email and password" do
    test "logs the user in", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => valid_user_password()}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with remember me", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_frontman_server_web_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the user in with return to", %{conn: conn, user: user} do
      user = set_password(user)

      conn =
        conn
        |> init_test_session(user_return_to: "/foo/bar")
        |> post(~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "emits error message with invalid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in?mode=password", %{
          "user" => %{"email" => user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "Sign in to Frontman"
      assert response =~ "Invalid email or password"
    end
  end

  describe "POST /users/log-in - magic link" do
    test "sends magic link email when user exists", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "If your email is in our system"
      assert FrontmanServer.Repo.get_by!(Accounts.UserToken, user_id: user.id).context == "login"
    end

    test "logs the user in", %{conn: conn, user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token}
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "confirms unconfirmed user", %{conn: conn, unconfirmed_user: user} do
      {token, _hashed_token} = generate_user_magic_link_token(user)
      refute user.confirmed_at

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "User confirmed successfully."

      assert Accounts.get_user!(user.id).confirmed_at
    end

    test "emits error message when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"token" => "invalid"}
        })

      assert html_response(conn, 200) =~ "The link is invalid or it has expired."
    end
  end

  describe "DELETE /users/log-out" do
    test "logs the user out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> delete(~p"/users/log-out")
      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/users/log-out")
      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "passes return_to through to login page", %{conn: conn, user: user} do
      return_url = "http://localhost:3000/frontman"

      conn =
        conn |> log_in_user(user) |> delete(~p"/users/log-out?#{%{"return_to" => return_url}}")

      assert redirected_to(conn) ==
               "/users/log-in?return_to=http%3A%2F%2Flocalhost%3A3000%2Ffrontman"
    end
  end

  describe "GET /users/log-out" do
    test "renders a confirmation page instead of directly logging out", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(~p"/users/log-out")
      # GET should render the interstitial page, NOT destroy the session
      assert html_response(conn, 200) =~ "Signing out"
      # Session should still be intact — only DELETE destroys it
      assert get_session(conn, :user_token)
    end

    test "includes return_to as hidden field when provided", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/users/log-out?#{%{"return_to" => "http://localhost:3000/frontman"}}")

      assert html_response(conn, 200) =~ "http://localhost:3000/frontman"
    end
  end
end
