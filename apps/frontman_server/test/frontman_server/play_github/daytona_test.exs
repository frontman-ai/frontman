defmodule FrontmanServer.PlayGithub.DaytonaTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.PlayGithub.Daytona

  describe "create_sandbox/1" do
    test "creates Daytona sandbox with JSON attrs" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert conn.method == "POST"
        assert conn.request_path == "/api/sandbox"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        assert Jason.decode!(body) == %{
                 "name" => "playgithub-test",
                 "labels" => %{
                   "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
                 }
               }

        Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
      end)

      assert {:ok, %Req.Response{status: 200}} =
               Daytona.create_sandbox(%{
                 name: "playgithub-test",
                 labels: %{
                   "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
                 }
               })
    end
  end

  describe "get_sandbox/1" do
    test "fetches Daytona sandbox state" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/sandbox/sandbox_123"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
      end)

      assert {:ok, %Req.Response{status: 200, body: %{"state" => "started"}}} =
               Daytona.get_sandbox("sandbox_123")
    end
  end

  describe "start_sandbox/1" do
    test "starts Daytona sandbox" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/sandbox/sandbox_123/start"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
      end)

      assert {:ok, %Req.Response{status: 200, body: %{"state" => "started"}}} =
               Daytona.start_sandbox("sandbox_123")
    end
  end

  describe "create_signed_preview_url/3" do
    test "fetches a signed Daytona preview URL" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/sandbox/sandbox_123/ports/4321/signed-preview-url"
        assert conn.query_string == "expiresInSeconds=3600"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        Req.Test.json(conn, %{"url" => "https://4321-preview.proxy.daytona.work"})
      end)

      assert {:ok, %Req.Response{status: 200, body: %{"url" => preview_url}}} =
               Daytona.create_signed_preview_url("sandbox_123", 4321, 3600)

      assert preview_url == "https://4321-preview.proxy.daytona.work"
    end
  end

  describe "clone_repository/2" do
    test "asks Daytona to clone repo into workspace" do
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

      assert {:ok, %Req.Response{status: 200}} =
               Daytona.clone_repository("sandbox_123", "https://github.com/octocat/Hello-World")
    end
  end

  describe "execute_command/3" do
    test "runs a command in the sandbox workspace" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert conn.method == "POST"
        assert conn.request_path == "/api/toolbox/sandbox_123/toolbox/process/execute"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        assert Jason.decode!(body) == %{
                 "command" => "npx astro add @frontman-ai/astro --yes",
                 "cwd" => "workspace",
                 "timeout" => 300
               }

        Req.Test.json(conn, %{"exitCode" => 0, "result" => "installed"})
      end)

      assert {:ok, %Req.Response{status: 200, body: %{"exitCode" => 0}}} =
               Daytona.execute_command(
                 "sandbox_123",
                 "npx astro add @frontman-ai/astro --yes",
                 cwd: "workspace",
                 timeout_seconds: 300
               )
    end
  end

  describe "replace_labels/2" do
    test "replaces sandbox labels" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert conn.method == "PUT"
        assert conn.request_path == "/api/sandbox/sandbox_123/labels"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        assert Jason.decode!(body) == %{
                 "labels" => %{
                   "frontman.playgithub.cloned" => "true",
                   "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
                 }
               }

        Req.Test.json(conn, %{})
      end)

      assert {:ok, %Req.Response{status: 200}} =
               Daytona.replace_labels("sandbox_123", %{
                 "frontman.playgithub.cloned" => "true",
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               })
    end
  end
end
