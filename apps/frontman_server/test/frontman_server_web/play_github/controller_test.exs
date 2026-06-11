defmodule FrontmanServerWeb.PlayGithub.ControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  describe "GET / on playgithub.frontman.local" do
    test "redirects unauthenticated users to log in", %{conn: conn} do
      conn = get_playgithub(conn, ~p"/")

      assert redirected_to(conn) =~ "https://frontman.local:4002/users/log-in"
      assert login_return_to(conn) == "http://playgithub.frontman.local/"
    end

    test "redirects unauthenticated nested paths to log in", %{conn: conn} do
      conn = get_playgithub(conn, "/octocat/Hello-World")

      assert redirected_to(conn) =~ "https://frontman.local:4002/users/log-in"
      assert login_return_to(conn) == "http://playgithub.frontman.local/octocat/Hello-World"
    end
  end

  describe "GET / on playgithub.frontman.local for authenticated users" do
    setup :register_and_log_in_user

    test "confirms the PlayGithub host is routed", %{conn: conn} do
      conn = get_playgithub(conn, ~p"/")

      assert html_response(conn, 200) =~ "PlayGithub local subdomain is routed"
    end

    test "serves a launcher that advances commands to the sandbox preview", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-forwarded-proto", "https")
        |> put_req_header("x-forwarded-port", "4000")
        |> get_playgithub("/octocat/Hello-World")

      response = html_response(conn, 200)

      assert response =~ "Launching PlayGithub sandbox"
      assert response =~ ~s(let command = "create")
      assert response =~ ~s|data.next && data.next.startsWith("?command=")|
      assert response =~ ~s|if (next === "wait_for_clone") return "clone"|
      assert response =~ ~s|if (next === "wait_for_install") return "install"|
      assert response =~ ~s(return {command: "install", retry: true)
      assert response =~ ~s|if (next === "wait_for_dev_server") return "dev"|
      assert response =~ ~s(data.next === "open_frontman_preview")
      assert response =~ ~s(window.location.href = step.redirect)
    end

    test "rejects unsupported repository commands", %{conn: conn} do
      conn = get_playgithub(conn, "/octocat/Hello-World?command=build")

      assert text_response(conn, 400) =~ "error: unsupported_command"
      assert text_response(conn, 400) =~ "usage: ?command=create|start|clone|install|dev"
    end

    test "creates Daytona sandbox for new repository path", %{conn: conn} do
      expect_daytona_create_sandbox()

      conn = get_playgithub(conn, "/octocat/Hello-World?command=create")

      assert_response_lines(text_response(conn, 200), [
        "command: create",
        "repository_url: https://github.com/octocat/Hello-World",
        "workspace_path: workspace",
        "sandbox_id: sandbox_123",
        "status: sandbox_created",
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

  defp login_return_to(conn) do
    conn
    |> redirected_to()
    |> URI.parse()
    |> Map.fetch!(:query)
    |> URI.decode_query()
    |> Map.fetch!("return_to")
  end

  defp expect_daytona_create_sandbox do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/sandbox"

      assert %{
               "labels" => %{
                 "frontman.playgithub.github_url" => "https://github.com/octocat/Hello-World",
                 "frontman.playgithub.sandbox_id" => sandbox_record_id
               }
             } = Jason.decode!(body)

      assert is_binary(sandbox_record_id)

      Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
    end)
  end

  defp assert_response_lines(response, lines) do
    Enum.each(lines, fn line ->
      assert response =~ line
    end)
  end
end
