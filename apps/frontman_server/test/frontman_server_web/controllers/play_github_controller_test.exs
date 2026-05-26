defmodule FrontmanServerWeb.PlayGithubControllerTest do
  use FrontmanServerWeb.ConnCase

  alias FrontmanServer.Test.Fixtures.Accounts

  describe "GET / on playgithub.localhost" do
    test "redirects unauthenticated users to log in", %{conn: conn} do
      conn =
        conn
        |> Map.put(:host, "playgithub.localhost")
        |> get(~p"/")

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "uses the PlayGithub route for authenticated users", %{conn: conn} do
      user = Accounts.user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> Map.put(:host, "playgithub.localhost")
        |> get(~p"/")

      assert html_response(conn, 200) =~ "PlayGithub local subdomain is routed for #{user.email}"
    end
  end

  test "does not replace the default root route", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == "https://frontman.sh"
  end
end
