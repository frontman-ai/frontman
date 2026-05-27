defmodule FrontmanServerWeb.PlayGithubControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.PlayGithub

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

    test "uses the PlayGithub route for authenticated users", %{conn: conn} do
      conn = get_playgithub(conn, ~p"/")

      assert html_response(conn, 200) =~ "PlayGithub local subdomain is routed"
    end

    test "creates Daytona sandbox for new repository path", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_missing_sandbox(sandbox_name)
      expect_daytona_create_sandbox(sandbox_name)
      expect_daytona_replace_labels("cloning")
      expect_daytona_clone_repository()
      expect_daytona_replace_labels("cloned")

      conn = get_playgithub(conn, "/octocat/Hello-World")

      assert_response_lines(text_response(conn, 200), [
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: false",
        "clone_state: cloned",
        "next: open_frontman_editor"
      ])
    end

    test "reuses Daytona sandbox for existing repository path", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(sandbox_name)

      conn = get_playgithub(conn, "/octocat/Hello-World")

      assert_response_lines(text_response(conn, 200), [
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: already_cloned",
        "next: open_frontman_editor"
      ])
    end

    test "skips clone while existing sandbox is cloning", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloning"
      )

      conn = get_playgithub(conn, "/octocat/Hello-World")

      assert_response_lines(text_response(conn, 200), [
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloning",
        "next: open_frontman_editor"
      ])
    end

    test "rejects existing sandbox with mismatched repo label", %{conn: conn} do
      expect_daytona_get_existing_sandbox(
        sandbox_name(),
        "https://github.com/octocat/Spoon-Knife"
      )

      conn = get_playgithub(conn, "/octocat/Hello-World")

      assert text_response(conn, 409) =~ "error: daytona_repo_label_mismatch"
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
    {:ok, github_path} = PlayGithub.parse_path(["octocat", "Hello-World"])

    PlayGithub.sandbox_name(github_path)
  end

  defp expect_daytona_get_missing_sandbox(sandbox_name) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/sandbox/#{sandbox_name}"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{})
    end)
  end

  defp expect_daytona_get_existing_sandbox(sandbox_name) do
    expect_daytona_get_existing_sandbox(
      sandbox_name,
      "https://github.com/octocat/Hello-World",
      "cloned"
    )
  end

  defp expect_daytona_get_existing_sandbox(sandbox_name, repo_url) do
    expect_daytona_get_existing_sandbox(sandbox_name, repo_url, "cloned")
  end

  defp expect_daytona_get_existing_sandbox(sandbox_name, repo_url, clone_state) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/sandbox/#{sandbox_name}"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      Req.Test.json(conn, %{
        "id" => "sandbox_123",
        "labels" => %{
          "frontman.playgithub.cloned" => "true",
          "frontman.playgithub.clone_state" => clone_state,
          "frontman.playgithub.repo_url" => repo_url
        },
        "state" => "started"
      })
    end)
  end

  defp expect_daytona_create_sandbox(sandbox_name) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/sandbox"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "name" => sandbox_name,
               "labels" => %{
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             }

      Req.Test.json(conn, %{
        "id" => "sandbox_123",
        "state" => "started"
      })
    end)
  end

  defp expect_daytona_clone_repository do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/toolbox/sandbox_123/toolbox/git/clone"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "url" => "https://github.com/octocat/Hello-World",
               "path" => "workspace"
             }

      Req.Test.json(conn, %{})
    end)
  end

  defp expect_daytona_replace_labels("cloning") do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "labels" => %{
                 "frontman.playgithub.clone_state" => "cloning",
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             }

      Req.Test.json(conn, %{})
    end)
  end

  defp expect_daytona_replace_labels("cloned") do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "labels" => %{
                 "frontman.playgithub.cloned" => "true",
                 "frontman.playgithub.clone_state" => "cloned",
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             }

      Req.Test.json(conn, %{})
    end)
  end

  defp assert_response_lines(response, lines) do
    Enum.each(lines, fn line ->
      assert response =~ line
    end)
  end
end
