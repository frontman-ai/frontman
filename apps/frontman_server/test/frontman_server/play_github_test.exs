defmodule FrontmanServer.PlayGithubTest do
  use ExUnit.Case, async: false

  alias FrontmanServer.PlayGithub
  alias FrontmanServer.PlayGithub.GithubReference

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

    :ok
  end

  describe "sandbox_name/1" do
    test "returns stable Daytona sandbox name for repository URL" do
      {:ok, github_path} = GithubReference.parse_path(["octocat", "Hello-World"])

      {:ok, tree_path} =
        GithubReference.parse_path(["octocat", "Hello-World", "tree", "main", "app"])

      {:ok, other_path} = GithubReference.parse_path(["octocat", "Spoon-Knife"])

      sandbox_name = PlayGithub.sandbox_name(github_path)

      assert sandbox_name == PlayGithub.sandbox_name(github_path)
      assert sandbox_name != PlayGithub.sandbox_name(tree_path)
      assert sandbox_name != PlayGithub.sandbox_name(other_path)
      assert String.starts_with?(sandbox_name, "playgithub-")
      assert String.length(sandbox_name) == String.length("playgithub-") + 16
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

  describe "run_repository_command/3" do
    test "creates sandbox with single lifecycle label" do
      {:ok, github_reference} = GithubReference.parse_path(["octocat", "Hello-World"])
      sandbox_name = PlayGithub.sandbox_name(github_reference)

      expect_daytona_config()
      expect_daytona_get_missing_sandbox(sandbox_name)
      expect_daytona_create_sandbox(sandbox_name)

      assert {:ok, %{command: "create", sandbox: sandbox}} =
               PlayGithub.run_repository_command(github_reference, :create)

      assert sandbox.id == "sandbox_123"
      assert sandbox.name == sandbox_name
      assert sandbox.provider_state == :started
      assert sandbox.lifecycle == :sandbox_created
    end

    test "clones tree path through Daytona git API" do
      {:ok, github_reference} =
        GithubReference.parse_path([
          "octocat",
          "Hello-World",
          "tree",
          "main",
          "apps",
          "marketing"
        ])

      sandbox_name = PlayGithub.sandbox_name(github_reference)

      expect_daytona_config()
      expect_daytona_get_existing_sandbox(sandbox_name, "sandbox_created")
      expect_daytona_replace_lifecycle("clone_starting")

      assert {:ok, %{command: "clone", sandbox: sandbox}} =
               PlayGithub.run_repository_command(github_reference, :clone)

      assert sandbox.lifecycle == :clone_starting

      expect_daytona_git_clone(%{
        "branch" => "main",
        "path" => "workspace",
        "url" => "https://github.com/octocat/Hello-World"
      })

      expect_daytona_replace_lifecycle("clone_finished")
      run_background_job()
    end

    test "treats Daytona repository-exists clone conflict as cloned" do
      {:ok, github_reference} = GithubReference.parse_path(["octocat", "Hello-World"])
      sandbox_name = PlayGithub.sandbox_name(github_reference)

      expect_daytona_config()
      expect_daytona_get_existing_sandbox(sandbox_name, "sandbox_created")
      expect_daytona_replace_lifecycle("clone_starting")

      assert {:ok, %{command: "clone", sandbox: sandbox}} =
               PlayGithub.run_repository_command(github_reference, :clone)

      assert sandbox.lifecycle == :clone_starting

      expect_daytona_git_clone_repository_exists(%{
        "path" => "workspace",
        "url" => "https://github.com/octocat/Hello-World"
      })

      expect_daytona_replace_lifecycle("clone_finished")
      run_background_job()
    end

    test "installs frontman repository root as the marketing app" do
      {:ok, github_reference} = GithubReference.parse_path(["frontman-ai", "frontman"])
      sandbox_name = PlayGithub.sandbox_name(github_reference)
      repo_url = "https://github.com/frontman-ai/frontman"

      expect_daytona_config()
      expect_daytona_get_existing_sandbox(sandbox_name, "clone_finished", repo_url)
      expect_daytona_replace_lifecycle("install_starting", repo_url)

      assert {:ok, %{command: "install", sandbox: sandbox}} =
               PlayGithub.run_repository_command(github_reference, :install)

      assert sandbox.lifecycle == :install_starting

      expect_daytona_execute_command(fn body ->
        assert body["command"] == "test -d 'workspace/apps/marketing'"
        assert body["cwd"] == "."
      end)

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
        assert command =~ "skipping astro add"
        refute command =~ "npx astro add"
      end)

      expect_daytona_replace_lifecycle("install_finished", repo_url)
      run_background_job()
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:frontman_server, key)
  defp restore_env(key, value), do: Application.put_env(:frontman_server, key, value)

  defp run_background_job do
    assert_receive {:playgithub_background_job, job}
    job.()
  end

  defp expect_daytona_config do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/config"

      Req.Test.json(conn, %{"proxyToolboxUrl" => "https://daytona.test/toolbox"})
    end)
  end

  defp expect_daytona_get_missing_sandbox(sandbox_name) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/sandbox/#{sandbox_name}"

      Plug.Conn.send_resp(conn, 404, "")
    end)
  end

  defp expect_daytona_get_existing_sandbox(
         sandbox_name,
         lifecycle,
         repo_url \\ "https://github.com/octocat/Hello-World"
       ) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/sandbox/#{sandbox_name}"

      Req.Test.json(conn, %{
        "id" => "sandbox_123",
        "labels" => repository_labels(lifecycle, repo_url),
        "state" => "started"
      })
    end)
  end

  defp expect_daytona_create_sandbox(sandbox_name) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/sandbox"

      assert Jason.decode!(body) == %{
               "name" => sandbox_name,
               "labels" => repository_labels("sandbox_created")
             }

      Req.Test.json(conn, %{"id" => "sandbox_123", "state" => "started"})
    end)
  end

  defp expect_daytona_replace_lifecycle(
         lifecycle,
         repo_url \\ "https://github.com/octocat/Hello-World"
       ) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"

      labels = Jason.decode!(body)["labels"]

      assert labels["frontman.playgithub.repo_url"] == repo_url
      assert labels["frontman.playgithub.lifecycle"] == lifecycle

      if lifecycle in ["clone_starting", "install_starting"] do
        assert {_, ""} = Integer.parse(labels["frontman.playgithub.lifecycle_started_at"])
      end

      Req.Test.json(conn, %{})
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

  defp expect_daytona_git_clone_repository_exists(expected_body) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/toolbox/sandbox_123/git/clone"
      assert Jason.decode!(body) == expected_body

      body =
        Jason.encode!(%{
          "code" => "CONFLICT",
          "message" => "conflict: repository already exists",
          "method" => "POST",
          "path" => "/git/clone",
          "statusCode" => 409
        })

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(409, body)
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

  defp repository_labels(lifecycle, repo_url \\ "https://github.com/octocat/Hello-World") do
    %{
      "frontman.playgithub.lifecycle" => lifecycle,
      "frontman.playgithub.repo_url" => repo_url
    }
  end
end
