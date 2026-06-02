defmodule FrontmanServerWeb.PlayGithub.ControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  alias FrontmanServer.PlayGithub
  alias FrontmanServer.PlayGithub.GithubReference

  describe "GET / on playgithub.frontman.local" do
    test "redirects unauthenticated users to log in", %{conn: conn} do
      conn = get_playgithub(conn, ~p"/")

      assert redirected_to(conn) =~ "https://frontman.local:4002/users/log-in"
      assert redirected_to(conn) =~ "return_to="
    end

    test "redirects unauthenticated nested paths to log in", %{conn: conn} do
      conn = get_playgithub(conn, "/octocat/Hello-World")

      assert redirected_to(conn) =~ "https://frontman.local:4002/users/log-in"
      assert redirected_to(conn) =~ "return_to="
    end
  end

  describe "GET / on playgithub.frontman.local for authenticated users" do
    setup :register_and_log_in_user

    test "routes authenticated users through PlayGithub", %{conn: conn} do
      conn = get_playgithub(conn, ~p"/")

      assert text_response(conn, 400) =~ "error: missing_owner_or_repo"
    end

    test "requires explicit repository command", %{conn: conn} do
      conn = get_playgithub(conn, "/octocat/Hello-World")

      assert text_response(conn, 400) =~ "error: missing_command"
    end

    test "rejects unsupported repository commands", %{conn: conn} do
      conn = get_playgithub(conn, "/octocat/Hello-World?command=build")

      assert text_response(conn, 400) =~ "error: unsupported_command"
      assert text_response(conn, 400) =~ "usage: ?command=create|start|clone|install|dev"
    end

    test "creates Daytona sandbox for new repository path", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_config()
      expect_daytona_get_missing_sandbox(sandbox_name)
      expect_daytona_create_sandbox(sandbox_name)

      conn = get_playgithub(conn, "/octocat/Hello-World?command=create")

      assert_response_lines(text_response(conn, 200), [
        "command: create",
        "repository_url: https://github.com/octocat/Hello-World",
        "workspace_path: workspace",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "provider_state: started",
        "lifecycle: sandbox_created",
        "next: ?command=clone"
      ])
    end

    test "reports issue paths without repository sandbox orchestration", %{conn: conn} do
      conn = get_playgithub(conn, "/octocat/Hello-World/issues/123?command=create")

      assert text_response(conn, 400) == "error: not_repository_path"
    end
  end

  test "does not replace the default root route", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == "https://frontman.sh"
  end

  defp get_playgithub(conn, path) do
    conn
    |> Map.put(:host, "playgithub.frontman.local")
    |> get(path)
  end

  defp sandbox_name do
    {:ok, github_path} = GithubReference.parse_path(["octocat", "Hello-World"])

    PlayGithub.sandbox_name(github_path)
  end

  defp expect_daytona_config do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/config"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      Req.Test.json(conn, %{"proxyToolboxUrl" => "https://daytona.test/toolbox"})
    end)
  end

  defp expect_daytona_get_missing_sandbox(sandbox_name) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/sandbox/#{sandbox_name}"

      Plug.Conn.send_resp(conn, 404, "")
    end)
  end

  defp expect_daytona_create_sandbox(sandbox_name) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/sandbox"

      assert Jason.decode!(body) == %{
               "name" => sandbox_name,
               "labels" => %{
                 "frontman.playgithub.lifecycle" => "sandbox_created",
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             }

      Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
    end)
  end

  defp assert_response_lines(response, lines) do
    Enum.each(lines, fn line ->
      assert response =~ line
    end)
  end
end
