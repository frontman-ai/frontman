defmodule FrontmanServer.Sandbox.RepoAnalyzerTest do
  use ExUnit.Case, async: true

  import Mox

  alias FrontmanServer.Sandbox.{EnvironmentSpec, RepoAnalyzer}

  setup :verify_on_exit!

  @token "ghp_test_token"
  @repo "owner/my-repo"
  @devcontainer_json ~s({"image":"mcr.microsoft.com/devcontainers/base:ubuntu"})

  defp analyze(opts \\ []) do
    RepoAnalyzer.analyze(@repo, @token, [github_client: MockGitHubClient] ++ opts)
  end

  defp tree_entry(path), do: %{"path" => path, "type" => "blob"}

  defp stub_tree(paths) do
    MockGitHubClient
    |> expect(:get_tree, fn "owner", "my-repo", "HEAD", @token ->
      {:ok, Enum.map(paths, &tree_entry/1)}
    end)
  end

  defp stub_file(path, content) do
    MockGitHubClient
    |> expect(:get_file, fn "owner", "my-repo", ^path, @token ->
      {:ok, content}
    end)
  end

  describe "analyze/3 - happy paths" do
    test "finds .devcontainer/devcontainer.json" do
      stub_tree([".devcontainer/devcontainer.json", "README.md"])
      stub_file(".devcontainer/devcontainer.json", @devcontainer_json)

      assert {:ok,
              %EnvironmentSpec{
                contents: %{"image" => "mcr.microsoft.com/devcontainers/base:ubuntu"}
              }} = analyze()
    end

    test "finds .devcontainer.json at root" do
      stub_tree([".devcontainer.json", "README.md"])
      stub_file(".devcontainer.json", @devcontainer_json)

      assert {:ok, %EnvironmentSpec{}} = analyze()
    end

    test "finds devcontainer.json at root" do
      stub_tree(["src/main.ex", "devcontainer.json"])
      stub_file("devcontainer.json", @devcontainer_json)

      assert {:ok, %EnvironmentSpec{}} = analyze()
    end
  end

  describe "analyze/3 - priority" do
    test ".devcontainer/devcontainer.json wins over .devcontainer.json" do
      stub_tree([".devcontainer/devcontainer.json", ".devcontainer.json"])
      stub_file(".devcontainer/devcontainer.json", @devcontainer_json)

      assert {:ok, %EnvironmentSpec{}} = analyze()
    end
  end

  describe "analyze/3 - error cases" do
    test "no devcontainer in tree returns :no_devcontainer" do
      stub_tree(["README.md", "src/main.ex"])

      assert {:error, :no_devcontainer} = analyze()
    end

    test "invalid JSON returns :invalid_json" do
      stub_tree([".devcontainer/devcontainer.json"])
      stub_file(".devcontainer/devcontainer.json", "not json {{{")

      assert {:error, :invalid_json} = analyze()
    end

    test "empty devcontainer map returns :empty_devcontainer" do
      stub_tree([".devcontainer/devcontainer.json"])
      stub_file(".devcontainer/devcontainer.json", "{}")

      assert {:error, :empty_devcontainer} = analyze()
    end

    test "401 from get_tree returns :unauthorized" do
      MockGitHubClient
      |> expect(:get_tree, fn _, _, _, _ ->
        {:error, {:http_error, 401, "Unauthorized"}}
      end)

      assert {:error, :unauthorized} = analyze()
    end

    test "404 from get_tree returns :not_found" do
      MockGitHubClient
      |> expect(:get_tree, fn _, _, _, _ ->
        {:error, {:http_error, 404, "Not Found"}}
      end)

      assert {:error, :not_found} = analyze()
    end

    test "other non-2xx from get_tree returns {:github_error, status, body}" do
      MockGitHubClient
      |> expect(:get_tree, fn _, _, _, _ ->
        {:error, {:http_error, 503, "Service Unavailable"}}
      end)

      assert {:error, {:github_error, 503, "Service Unavailable"}} = analyze()
    end

    test "network error from get_tree is propagated" do
      MockGitHubClient
      |> expect(:get_tree, fn _, _, _, _ ->
        {:error, :econnrefused}
      end)

      assert {:error, :econnrefused} = analyze()
    end

    test "repo string without slash returns :invalid_repo_format" do
      assert {:error, :invalid_repo_format} =
               RepoAnalyzer.analyze("my-repo", @token, github_client: MockGitHubClient)
    end
  end
end
