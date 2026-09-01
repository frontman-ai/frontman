defmodule FrontmanServerWeb.EmbeddedClientAuthControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts
  alias FrontmanServerWeb.EmbeddedClientAuth

  setup do
    %{user: user_fixture()}
  end

  describe "GET /users/popup-complete" do
    test "redirects unauthenticated users to login", %{conn: conn} do
      conn = get(conn, ~p"/users/popup-complete")

      assert redirected_to(conn) == "/users/log-in?return_to=%2Fusers%2Fpopup-complete"
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end

    test "shows consent for the exact pending origin", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> put_session(EmbeddedClientAuth.pending_session_key(), %{
          "origin" => "https://customer.example",
          "state" => "state-123"
        })
        |> get(~p"/users/popup-complete")

      response = html_response(conn, 200)
      assert response =~ "Connect this site to Frontman?"
      assert response =~ "https://customer.example"
      assert response =~ "Why am I seeing this?"
      assert response =~ "What will happen?"
      assert response =~ "Allow and continue"
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end

    test "shows safe fallback when no request is pending", %{conn: conn, user: user} do
      conn = conn |> log_in_user(user) |> get(~p"/users/popup-complete")

      response = html_response(conn, 200)
      assert response =~ "Authentication complete"
      assert response =~ "You may close this window"
      refute response =~ "postMessage"
    end
  end

  describe "POST /users/popup-complete" do
    test "mints token and posts completion to exact origin", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> put_session(EmbeddedClientAuth.pending_session_key(), %{
          "origin" => "https://customer.example",
          "state" => "state-123"
        })
        |> post(~p"/users/popup-complete")

      response = html_response(conn, 200)
      assert response =~ "Authorization complete"
      assert response =~ ~s(id="embedded-client-auth-completion")
      assert response =~ ~s(data-origin="https://customer.example")
      assert response =~ ~s(data-state="state-123")
      assert response =~ ~s(data-token=)
      refute response =~ "window.opener.postMessage"
      assert get_session(conn, EmbeddedClientAuth.pending_session_key()) == nil
      assert get_resp_header(conn, "cache-control") == ["no-store"]

      stored_token = FrontmanServer.Repo.get_by!(Accounts.UserToken, context: "embedded_client")
      assert stored_token.context == "embedded_client"
      assert stored_token.approved_origin == "https://customer.example"
      refute conn.query_string =~ "token"
    end

    test "does not mint a token without an authenticated user", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{
          EmbeddedClientAuth.pending_session_key() => %{
            "origin" => "https://customer.example",
            "state" => "state-123"
          }
        })
        |> post(~p"/users/popup-complete")

      assert html_response(conn, 401) =~ "Authentication complete"
      refute FrontmanServer.Repo.get_by(Accounts.UserToken, context: "embedded_client")
    end
  end
end
