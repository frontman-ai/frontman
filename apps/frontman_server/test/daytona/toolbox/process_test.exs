defmodule Daytona.Toolbox.ProcessTest do
  use ExUnit.Case, async: true

  alias Daytona.Toolbox
  alias Daytona.Toolbox.Process, as: ToolboxProcess

  describe "execute/4" do
    test "runs a command in the sandbox workspace" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert conn.method == "POST"
        assert conn.request_path == "/toolbox/sandbox_123/process/execute"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        assert Jason.decode!(body) == %{
                 "command" => "npx astro add @frontman-ai/astro --yes",
                 "cwd" => "workspace",
                 "envs" => %{"NODE_ENV" => "test"},
                 "timeout" => 300
               }

        Req.Test.json(conn, %{"exitCode" => 0, "result" => "installed"})
      end)

      assert {:ok, %{exit_code: 0, body: %{"exitCode" => 0, "result" => "installed"}}} =
               ToolboxProcess.execute(toolbox(), "sandbox_123", %{
                 command: "npx astro add @frontman-ai/astro --yes",
                 cwd: "workspace",
                 envs: %{"NODE_ENV" => "test"},
                 timeout: 300
               })
    end
  end

  defp toolbox do
    %Toolbox{daytona: Daytona.new(), proxyToolboxUrl: URI.parse("https://daytona.test/toolbox")}
  end
end
