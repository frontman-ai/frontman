defmodule FrontmanServer.PlayGithub.Daytona.ClientTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.PlayGithub.Daytona.Client

  describe "new/1" do
    test "loads toolbox proxy URL from Daytona config" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/config"
        assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
        assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

        Req.Test.json(conn, %{"proxyToolboxUrl" => "https://daytona.test/toolbox"})
      end)

      assert {:ok, %Client{proxyToolboxUrl: "https://daytona.test/toolbox"}} = Client.new()
    end

    test "rejects malformed Daytona config" do
      Req.Test.expect(:playgithub_daytona, fn conn ->
        Req.Test.json(conn, %{"proxyToolboxUrl" => 123})
      end)

      assert {:error, {:malformed_daytona_config, error}} = Client.new()
      assert error =~ "proxyToolboxUrl"
    end
  end
end
