defmodule FrontmanServerWeb.EmbeddedClientLoginTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts
  alias FrontmanServer.Repo

  @request %{"embedded_origin" => "https://customer.example", "embedded_state" => "state-123"}

  setup do
    %{user: user_fixture()}
  end

  test "popup completion is inert for signed-in and signed-out users", %{conn: conn, user: user} do
    for conn <- [conn, log_in_user(conn, user)] do
      conn = get(conn, ~p"/users/popup-complete")
      response = html_response(conn, 200)
      assert response =~ "Authentication complete"
      refute response =~ "embedded-client-auth-completion"
      refute response =~ "postMessage"
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end

    refute Repo.get_by(Accounts.UserToken, context: "embedded_client")
  end

  test "connect POST issues a token bound to the submitted origin", %{conn: conn, user: user} do
    conn =
      conn
      |> log_in_user(user)
      |> post(
        ~p"/users/log-in",
        Map.merge(@request, %{"_action" => "connect", "user_id" => user.id})
      )

    response = html_response(conn, 200)
    assert response =~ ~s(data-origin="https://customer.example")
    assert response =~ ~s(data-state="state-123")
    assert [_, token] = Regex.run(~r/data-token="([^"]+)"/, response)

    assert {scope, _} =
             Accounts.get_scope_by_embedded_client_token(token, "https://customer.example")

    assert scope.user.id == user.id
    refute Accounts.get_scope_by_embedded_client_token(token, "https://other.example")

    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end

  test "connect requires an authenticated user", %{conn: conn} do
    conn = post(conn, ~p"/users/log-in", Map.put(@request, "_action", "connect"))

    assert response(conn, 401)
    refute Repo.get_by(Accounts.UserToken, context: "embedded_client")
  end

  test "connect rejects a different signed-in account", %{conn: conn, user: user} do
    other = user_fixture()

    conn =
      conn
      |> log_in_user(user)
      |> post(
        ~p"/users/log-in",
        Map.merge(@request, %{"_action" => "connect", "user_id" => other.id})
      )

    assert response(conn, 401)
    refute Repo.get_by(Accounts.UserToken, context: "embedded_client")
  end

  test "connect rejects a request without CSRF protection", %{conn: conn, user: user} do
    conn = conn |> log_in_user(user) |> put_private(:plug_skip_csrf_protection, false)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      post(conn, ~p"/users/log-in", Map.put(@request, "_action", "connect"))
    end

    refute Repo.get_by(Accounts.UserToken, context: "embedded_client")
  end

  test "OAuth transaction survives unrelated login and rejects an older callback", %{conn: conn} do
    conn =
      post(conn, ~p"/auth/github", %{
        "embedded_origin" => "https://first.example",
        "embedded_state" => "first"
      })

    first = get_session(conn, :oauth_signin_state)

    assert %{
             "state" => first_state,
             "embedded_request" => %{"origin" => "https://first.example", "state" => "first"}
           } = first

    assert is_binary(first_state)

    conn =
      get(
        conn,
        ~p"/users/log-in?#{%{"embedded_origin" => "https://other.example", "embedded_state" => "other"}}"
      )

    assert get_session(conn, :oauth_signin_state) == first

    conn =
      post(conn, ~p"/auth/github", %{
        "embedded_origin" => "https://second.example",
        "embedded_state" => "second"
      })

    second = get_session(conn, :oauth_signin_state)

    assert %{
             "state" => second_state,
             "embedded_request" => %{"origin" => "https://second.example", "state" => "second"}
           } = second

    refute second_state == first_state

    conn = get(conn, ~p"/auth/callback?#{%{"state" => first_state, "error" => "access_denied"}}")
    assert redirected_to(conn) == ~p"/users/log-in"
    assert get_session(conn, :oauth_signin_state) == second

    conn = get(conn, ~p"/auth/callback?#{%{"state" => second_state, "error" => "access_denied"}}")
    assert redirected_to(conn) == ~p"/users/log-in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Sign in was cancelled."
    refute get_session(conn, :oauth_signin_state)
  end

  test "OAuth initiation rejects missing CSRF tokens", %{conn: conn} do
    conn = put_private(conn, :plug_skip_csrf_protection, false)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      post(conn, ~p"/auth/github", %{})
    end
  end

  test "stale email verification cannot complete another tab's request", %{conn: conn} do
    pending = %{
      "token" => "not-exchanged",
      "email" => "user@example.com",
      "state" => "new",
      "request" => %{"origin" => "https://customer.example", "state" => "state-123"}
    }

    conn = init_test_session(conn, pending_auth: pending)
    assert html_response(get(conn, ~p"/auth/verify-email"), 200) =~ ~s(name="state" value="new")

    for state <- [nil, "old"] do
      rejected = post(conn, ~p"/auth/verify-email", %{"code" => "123456", "state" => state})
      assert redirected_to(rejected) == ~p"/users/log-in"
      assert get_session(rejected, :pending_auth) == pending
      refute Repo.get_by(Accounts.UserToken, context: "embedded_client")
    end
  end
end
