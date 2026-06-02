defmodule FrontmanServer.PlayGithub.Daytona.ToolboxTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.PlayGithub.Daytona.Toolbox

  describe "execute_command/3" do
    test "runs a command in the sandbox workspace" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/config"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        Req.Test.json(conn, %{"proxyToolboxUrl" => "https://daytona.test/toolbox"})
      end)

      Req.Test.expect(:playgithub_daytona, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert conn.method == "POST"
        assert conn.request_path == "/toolbox/sandbox_123/process/execute"
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
               Toolbox.execute_command(
                 "sandbox_123",
                 "npx astro add @frontman-ai/astro --yes",
                 cwd: "workspace",
                 timeout_seconds: 300
               )
    end
  end
end
