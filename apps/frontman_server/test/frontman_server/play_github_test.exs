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

  defp expect_daytona_get_existing_sandbox(sandbox_name, lifecycle) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/sandbox/#{sandbox_name}"

      Req.Test.json(conn, %{
        "id" => "sandbox_123",
        "labels" => repository_labels(lifecycle),
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

  defp expect_daytona_replace_lifecycle(lifecycle) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"

      labels = Jason.decode!(body)["labels"]

      assert labels["frontman.playgithub.repo_url"] == "https://github.com/octocat/Hello-World"
      assert labels["frontman.playgithub.lifecycle"] == lifecycle

      if lifecycle in ["clone_starting"] do
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

  defp repository_labels(lifecycle) do
    %{
      "frontman.playgithub.lifecycle" => lifecycle,
      "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
    }
  end
end
