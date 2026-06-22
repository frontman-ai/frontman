defmodule Daytona.SandboxTest do
  use ExUnit.Case, async: true

  alias Daytona.Sandbox

  describe "create/2" do
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

      assert {:ok, %{id: "sandbox_123"}} =
               Sandbox.create(daytona(), %{
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

      assert {:ok, %{id: "sandbox_123"}} =
               Sandbox.create(daytona(), %{
                 name: "playgithub-test",
                 snapshot: "ubuntu-4vcpu-8ram-100gb",
                 user: "daytona",
                 env: %{"NODE_ENV" => "production"},
                 labels: %{"daytona.io/public" => "true"},
                 public: false,
                 networkBlockAll: true,
                 networkAllowList: "192.168.1.0/16",
                 target: "us",
                 cpu: 2,
                 gpu: 1,
                 memory: 4,
                 disk: 20,
                 autoStopInterval: 30,
                 autoArchiveInterval: 10_080,
                 autoDeleteInterval: 0,
                 buildInfo: %{
                   dockerfileContent: "FROM node:20",
                   contextHashes: ["hash1"]
                 },
                 linkedSandbox: "sandbox-parent"
               })
    end
  end

  describe "get/2" do
    test "fetches Daytona sandbox state" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/sandbox/sandbox_123"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
      end)

      assert {:ok, %{"id" => "sandbox_123", "state" => "started"}} =
               Sandbox.get(daytona(), "sandbox_123")
    end
  end

  describe "start/2" do
    test "starts Daytona sandbox" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/sandbox/sandbox_123/start"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
      end)

      assert :started = Sandbox.start(daytona(), "sandbox_123")
    end
  end

  describe "get_preview_link/3" do
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

      assert {:ok, %{url: preview_url, preview_token: "preview-token"}} =
               Sandbox.get_preview_link(daytona(), "sandbox_123", 4321)

      assert preview_url == "https://4321-sandbox-123.proxy.daytona.work"
    end
  end

  defp daytona do
    Daytona.new()
  end
end
