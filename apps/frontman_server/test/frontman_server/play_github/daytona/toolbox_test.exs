defmodule FrontmanServer.PlayGithub.Daytona.ToolboxTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.PlayGithub.Daytona
  alias FrontmanServer.PlayGithub.Daytona.Toolbox

  describe "fetch/1" do
    test "loads toolbox proxy URL from Daytona config" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/config"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        Req.Test.json(conn, %{"proxyToolboxUrl" => "https://daytona.test/toolbox"})
      end)

      daytona = Daytona.new()

      proxy_toolbox_url = URI.parse("https://daytona.test/toolbox")

      assert {:ok,
              %Toolbox{
                daytona: ^daytona,
                proxyToolboxUrl: ^proxy_toolbox_url
              }} = Toolbox.fetch(daytona)
    end

    test "rejects malformed Daytona config" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        Req.Test.json(conn, %{"proxyToolboxUrl" => 123})
      end)

      assert {:error, {:malformed_daytona_config, error}} = Toolbox.fetch(Daytona.new())
      assert error =~ "proxyToolboxUrl"
    end

    test "rejects malformed toolbox URLs" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        Req.Test.json(conn, %{"proxyToolboxUrl" => "daytona.test/toolbox"})
      end)

      assert {:error, {:malformed_daytona_config, error}} = Toolbox.fetch(Daytona.new())
      assert error =~ "proxyToolboxUrl"
    end
  end
end
