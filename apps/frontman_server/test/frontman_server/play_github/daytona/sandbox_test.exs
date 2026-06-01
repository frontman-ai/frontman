defmodule FrontmanServer.PlayGithub.Daytona.SandboxTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.PlayGithub.Daytona.Sandbox
  alias FrontmanServer.PlayGithub.Daytona.Sandbox.{CreateBuildInfo, CreateSandbox}

  describe "create/1" do
    test "creates Daytona sandbox with typed attrs" do
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
               Sandbox.create(%CreateSandbox{
                 name: "playgithub-test",
                 labels: %{
                   "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
                 }
               })
    end

    test "encodes Daytona create sandbox fields" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert conn.method == "POST"
        assert conn.request_path == "/api/sandbox"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        assert Jason.decode!(body) == %{
                 "name" => "playgithub-test",
                 "snapshot" => "ubuntu-4vcpu-8ram-100gb",
                 "user" => "daytona",
                 "env" => %{"NODE_ENV" => "production"},
                 "labels" => %{"daytona.io/public" => "true"},
                 "public" => false,
                 "networkBlockAll" => true,
                 "networkAllowList" => "192.168.1.0/16",
                 "target" => "us",
                 "cpu" => 2,
                 "gpu" => 1,
                 "memory" => 4,
                 "disk" => 20,
                 "autoStopInterval" => 30,
                 "autoArchiveInterval" => 10_080,
                 "autoDeleteInterval" => 0,
                 "buildInfo" => %{
                   "dockerfileContent" => "FROM node:20",
                   "contextHashes" => ["hash1"]
                 },
                 "linkedSandbox" => "sandbox-parent"
               }

        Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
      end)

      assert {:ok, %Req.Response{status: 200}} =
               Sandbox.create(%CreateSandbox{
                 name: "playgithub-test",
                 snapshot: "ubuntu-4vcpu-8ram-100gb",
                 user: "daytona",
                 env: %{"NODE_ENV" => "production"},
                 labels: %{"daytona.io/public" => "true"},
                 public: false,
                 network_block_all: true,
                 network_allow_list: "192.168.1.0/16",
                 target: "us",
                 cpu: 2,
                 gpu: 1,
                 memory: 4,
                 disk: 20,
                 auto_stop_interval: 30,
                 auto_archive_interval: 10_080,
                 auto_delete_interval: 0,
                 build_info: %CreateBuildInfo{
                   dockerfile_content: "FROM node:20",
                   context_hashes: ["hash1"]
                 },
                 linked_sandbox: "sandbox-parent"
               })
    end
  end

  describe "get/1" do
    test "fetches Daytona sandbox state" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/sandbox/sandbox_123"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
      end)

      assert {:ok, %Req.Response{status: 200, body: %{"state" => "started"}}} =
               Sandbox.get("sandbox_123")
    end
  end

  describe "start/1" do
    test "starts Daytona sandbox" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/sandbox/sandbox_123/start"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
      end)

      assert {:ok, %Req.Response{status: 200, body: %{"state" => "started"}}} =
               Sandbox.start("sandbox_123")
    end
  end

  describe "get_signed_preview_url/3" do
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
               Sandbox.get_signed_preview_url("sandbox_123", 4321, 3600)

      assert preview_url == "https://4321-preview.proxy.daytona.work"
    end
  end

  describe "get_preview_link/2" do
    test "fetches a Daytona sandbox preview link for a port" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/sandbox/sandbox_123/ports/4321/preview-url"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        Req.Test.json(conn, %{
          "token" => "preview-token",
          "url" => "https://4321-sandbox-123.proxy.daytona.work"
        })
      end)

      assert {:ok, %Req.Response{status: 200, body: %{"url" => preview_url}}} =
               Sandbox.get_preview_link("sandbox_123", 4321)

      assert preview_url == "https://4321-sandbox-123.proxy.daytona.work"
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
               Sandbox.replace_labels("sandbox_123", %{
                 "frontman.playgithub.cloned" => "true",
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               })
    end
  end
end
