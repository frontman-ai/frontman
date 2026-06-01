defmodule FrontmanServer.PlayGithubTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.PlayGithub
  alias FrontmanServer.PlayGithub.GithubReference

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
end
