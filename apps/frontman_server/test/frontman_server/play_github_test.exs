defmodule FrontmanServer.PlayGithubTest do
  use FrontmanServer.DataCase, async: false

  alias FrontmanServer.PlayGithub
  alias FrontmanServer.PlayGithub.GithubReference
  alias FrontmanServer.PlayGithub.Sandbox
  alias FrontmanServer.Repo

  setup do
    previous_playgithub = Application.get_env(:frontman_server, :playgithub)
    test_pid = self()

    playgithub_config = previous_playgithub || []

    Application.put_env(
      :frontman_server,
      :playgithub,
      Keyword.put(playgithub_config, :background_runner, fn fun ->
        send(test_pid, {:playgithub_background_job, fun})
        {:ok, test_pid}
      end)
    )

    on_exit(fn -> restore_env(:playgithub, previous_playgithub) end)

    scope = FrontmanServer.Test.Fixtures.Accounts.user_scope_fixture()

    {:ok, scope: scope}
  end

  describe "github_url/1" do
    test "includes tree refs and paths" do
      {:ok, repo} = GithubReference.parse_path(["octocat", "Hello-World"])

      {:ok, tree} =
        GithubReference.parse_path(["octocat", "Hello-World", "tree", "main", "app"])

      assert GithubReference.github_url(repo) == "https://github.com/octocat/Hello-World"

      assert GithubReference.github_url(tree) ==
               "https://github.com/octocat/Hello-World/tree/main/app"
    end
  end

  describe "workspace_path/1" do
    test "uses marketing app for the frontman repository root" do
      {:ok, frontman_root} = GithubReference.parse_path(["frontman-ai", "frontman"])

      {:ok, frontman_tree_path} =
        GithubReference.parse_path(["frontman-ai", "frontman", "tree", "main", "libs"])

      {:ok, other_root} = GithubReference.parse_path(["octocat", "Hello-World"])

      assert PlayGithub.workspace_path(frontman_root) == "workspace/apps/marketing"
      assert PlayGithub.workspace_path(frontman_tree_path) == "workspace/libs"
      assert PlayGithub.workspace_path(other_root) == "workspace"
    end
  end

  describe "run_repository_command/4" do
    test "creates db row before Daytona sandbox", %{scope: scope} do
      {:ok, github_reference} = GithubReference.parse_path(["octocat", "Hello-World"])

      expect_daytona_create_sandbox("https://github.com/octocat/Hello-World")

      assert {:ok, %{command: "create", sandbox: sandbox}} =
               PlayGithub.run_repository_command(scope, github_reference, :create)

      assert sandbox.daytona_sandbox_id == "sandbox_123"
      assert sandbox.status == :sandbox_created

      assert %Sandbox{daytona_sandbox_id: "sandbox_123", status: :sandbox_created} =
               Repo.get_by(Sandbox, github_url: "https://github.com/octocat/Hello-World")
    end

    test "same user gets separate sandbox rows for different tree paths", %{scope: scope} do
      {:ok, root} = GithubReference.parse_path(["octocat", "Hello-World"])
      {:ok, tree} = GithubReference.parse_path(["octocat", "Hello-World", "tree", "main", "app"])

      expect_daytona_create_sandbox("https://github.com/octocat/Hello-World", "sandbox_root")

      assert {:ok, %{sandbox: %{daytona_sandbox_id: "sandbox_root"}}} =
               PlayGithub.run_repository_command(scope, root, :create)

      expect_daytona_create_sandbox(
        "https://github.com/octocat/Hello-World/tree/main/app",
        "sandbox_tree"
      )

      assert {:ok, %{sandbox: %{daytona_sandbox_id: "sandbox_tree"}}} =
               PlayGithub.run_repository_command(scope, tree, :create)
    end

    test "loads existing sandbox from db", %{scope: scope} do
      {:ok, github_reference} = GithubReference.parse_path(["octocat", "Hello-World"])
      insert_sandbox(scope, github_reference, :sandbox_created)

      assert {:ok, %{command: "create", sandbox: sandbox}} =
               PlayGithub.run_repository_command(scope, github_reference, :create)

      assert sandbox.daytona_sandbox_id == "sandbox_123"
    end

    test "clones tree path through Daytona git API", %{scope: scope} do
      {:ok, github_reference} =
        GithubReference.parse_path([
          "octocat",
          "Hello-World",
          "tree",
          "main",
          "apps",
          "marketing"
        ])

      insert_sandbox(scope, github_reference, :sandbox_created)

      assert {:ok, %{command: "clone", sandbox: sandbox}} =
               PlayGithub.run_repository_command(scope, github_reference, :clone)

      assert sandbox.status == :clone_starting

      expect_daytona_start_sandbox()
      expect_daytona_toolbox_config()

      expect_daytona_git_clone(%{
        "branch" => "main",
        "commit_id" => "",
        "password" => "",
        "path" => "workspace",
        "url" => "https://github.com/octocat/Hello-World",
        "username" => ""
      })

      run_background_job()
      assert Repo.get!(Sandbox, sandbox.id).status == :clone_finished
    end

    test "installs frontman repository root as the marketing app", %{scope: scope} do
      {:ok, github_reference} = GithubReference.parse_path(["frontman-ai", "frontman"])
      insert_sandbox(scope, github_reference, :clone_finished)

      assert {:ok, %{command: "install", sandbox: sandbox}} =
               PlayGithub.run_repository_command(scope, github_reference, :install)

      assert sandbox.status == :install_starting

      expect_daytona_start_sandbox()
      expect_daytona_toolbox_config()

      expect_daytona_execute_command(
        &assert &1["command"] == "test -d 'workspace/apps/marketing'"
      )

      expect_daytona_execute_command(fn body ->
        command = body["command"]

        assert body["cwd"] == "."
        assert command =~ "apps/marketing/package.json"
        assert command =~ "@frontman-ai/astro"
        assert command =~ "npm:latest"
        assert command =~ "corepack yarn workspaces focus marketing"
        refute command =~ "corepack yarn install"
      end)

      expect_daytona_execute_command(fn body ->
        command = body["command"]

        assert body["cwd"] == "workspace/apps/marketing"
        assert command =~ "npx astro add @frontman-ai/astro --yes"
      end)

      run_background_job()
      assert Repo.get!(Sandbox, sandbox.id).status == :install_finished
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:frontman_server, key)
  defp restore_env(key, value), do: Application.put_env(:frontman_server, key, value)

  defp run_background_job do
    assert_receive {:playgithub_background_job, job}
    job.()
  end

  defp insert_sandbox(scope, github_reference, status) do
    user_id = FrontmanServer.Accounts.scope_user_id(scope)

    %Sandbox{user_id: user_id}
    |> Sandbox.create_changeset(%{github_url: GithubReference.github_url(github_reference)})
    |> Repo.insert!()
    |> Ecto.Changeset.change(daytona_sandbox_id: "sandbox_123", status: status)
    |> Repo.update!()
  end

  defp expect_daytona_toolbox_config do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/config"

      Req.Test.json(conn, %{"proxyToolboxUrl" => "https://daytona.test/toolbox"})
    end)
  end

  defp expect_daytona_start_sandbox do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/sandbox/sandbox_123/start"

      Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
    end)
  end

  defp expect_daytona_create_sandbox(github_url, sandbox_id \\ "sandbox_123") do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/sandbox"

      assert %{
               "labels" => %{
                 "frontman.playgithub.github_url" => ^github_url,
                 "frontman.playgithub.sandbox_id" => sandbox_record_id
               }
             } = Jason.decode!(body)

      assert is_binary(sandbox_record_id)

      Req.Test.json(conn, %{"id" => sandbox_id, "state" => "started"})
    end)
  end

  defp expect_daytona_git_clone(expected_body) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/toolbox/sandbox_123/git/clone"
      assert Jason.decode!(body) == expected_body

      Req.Test.json(conn, %{})
    end)
  end

  defp expect_daytona_execute_command(assert_body) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/toolbox/sandbox_123/process/execute"

      body = Jason.decode!(body)
      assert_body.(body)

      Req.Test.json(conn, %{"exitCode" => 0, "result" => ""})
    end)
  end
end
