defmodule FrontmanServer.PlayGithub.Daytona.Toolbox.GitTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.PlayGithub.Daytona.Client
  alias FrontmanServer.PlayGithub.Daytona.Toolbox.Git

  test "clones repository through Daytona git API" do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/config"

      Req.Test.json(conn, %{"proxyToolboxUrl" => "https://daytona.test/toolbox"})
    end)

    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/toolbox/sandbox_123/git/clone"

      assert Jason.decode!(body) == %{
               "branch" => "main",
               "path" => "workspace",
               "url" => "https://github.com/octocat/Hello-World"
             }

      Req.Test.json(conn, %{})
    end)

    assert {:ok, client} = Client.new()

    assert {:ok, %Req.Response{status: 200}} =
             Git.clone(client, "sandbox_123", %{
               branch: "main",
               path: "workspace",
               url: "https://github.com/octocat/Hello-World"
             })
  end
end
