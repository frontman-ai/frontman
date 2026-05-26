defmodule FrontmanServerWeb.PlayGithubControllerTest do
  use FrontmanServerWeb.ConnCase

  alias FrontmanServer.Test.Fixtures.Accounts

  describe "GET / on playgithub.localhost" do
    test "redirects unauthenticated users to log in", %{conn: conn} do
      conn =
        conn
        |> playgithub_conn()
        |> get(~p"/")

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "uses the PlayGithub route for authenticated users", %{conn: conn} do
      user = Accounts.user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> playgithub_conn()
        |> get(~p"/")

      assert html_response(conn, 200) =~ "PlayGithub local subdomain is routed for #{user.email}"
    end

    test "redirects unauthenticated nested paths to log in", %{conn: conn} do
      conn =
        conn
        |> playgithub_conn()
        |> get("/octocat/Hello-World")

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "prints repository path parts", %{conn: conn} do
      user = Accounts.user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> playgithub_conn()
        |> get("/octocat/Hello-World")

      response = text_response(conn, 200)

      assert response =~ "owner: octocat"
      assert response =~ "repo: Hello-World"
      assert response =~ "resource: repository"
      assert response =~ "raw_segments: octocat/Hello-World"
    end

    test "prints tree path parts", %{conn: conn} do
      user = Accounts.user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> playgithub_conn()
        |> get("/octocat/Hello-World/tree/main/apps/web")

      response = text_response(conn, 200)

      assert response =~ "owner: octocat"
      assert response =~ "repo: Hello-World"
      assert response =~ "resource: tree"
      assert response =~ "ref: main"
      assert response =~ "path: apps/web"
      assert response =~ "raw_segments: octocat/Hello-World/tree/main/apps/web"
    end

    test "prints issue path parts", %{conn: conn} do
      user = Accounts.user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> playgithub_conn()
        |> get("/octocat/Hello-World/issues/123")

      response = text_response(conn, 200)

      assert response =~ "owner: octocat"
      assert response =~ "repo: Hello-World"
      assert response =~ "resource: issue"
      assert response =~ "issue_number: 123"
      assert response =~ "raw_segments: octocat/Hello-World/issues/123"
    end

    test "rejects invalid issue numbers", %{conn: conn} do
      user = Accounts.user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> playgithub_conn()
        |> get("/octocat/Hello-World/issues/nope")

      assert text_response(conn, 400) == "error: invalid_issue_number"
    end
  end

  test "does not replace the default root route", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == "https://frontman.sh"
  end

  defp playgithub_conn(conn) do
    Map.put(conn, :host, "playgithub.localhost")
  end
end
