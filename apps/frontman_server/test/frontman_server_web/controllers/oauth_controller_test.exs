defmodule FrontmanServerWeb.OAuthControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  setup do
    %{user: user_fixture()}
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
end
