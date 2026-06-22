defmodule Daytona.Toolbox.GitTest do
  use ExUnit.Case, async: true

  alias Daytona.Toolbox
  alias Daytona.Toolbox.Git

  test "clones repository through Daytona git API" do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/toolbox/sandbox_123/git/clone"

      assert Jason.decode!(body) == %{
               "branch" => "main",
               "commit_id" => "abc123",
               "password" => "ghp_secret",
               "path" => "workspace",
               "url" => "https://github.com/octocat/Hello-World",
               "username" => "octocat"
             }

      Req.Test.json(conn, %{})
    end)

    assert :ok =
             Git.clone(toolbox(), "sandbox_123", %{
               branch: "main",
               commit_id: "abc123",
               password: "ghp_secret",
               path: "workspace",
               url: "https://github.com/octocat/Hello-World",
               username: "octocat"
             })
  end

  defp toolbox do
    %Toolbox{daytona: Daytona.new(), proxyToolboxUrl: URI.parse("https://daytona.test/toolbox")}
  end
end
