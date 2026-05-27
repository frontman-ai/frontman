defmodule FrontmanServer.PlayGithubTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.PlayGithub

  describe "parse_path/1" do
    test "parses repository paths" do
      assert {:ok, github_path} = PlayGithub.parse_path(["octocat", "Hello-World"])

      assert PlayGithub.format_path(github_path) ==
               join_lines([
                 "owner: octocat",
                 "repo: Hello-World",
                 "github_url: https://github.com/octocat/Hello-World",
                 "resource: repository",
                 "raw_segments: octocat/Hello-World"
               ])
    end

    test "parses tree paths" do
      assert {:ok, github_path} =
               PlayGithub.parse_path(["octocat", "Hello-World", "tree", "main", "apps", "web"])

      assert PlayGithub.format_path(github_path) ==
               join_lines([
                 "owner: octocat",
                 "repo: Hello-World",
                 "github_url: https://github.com/octocat/Hello-World",
                 "resource: tree",
                 "ref: main",
                 "path: apps/web",
                 "raw_segments: octocat/Hello-World/tree/main/apps/web"
               ])
    end

    test "parses issue paths" do
      assert {:ok, github_path} =
               PlayGithub.parse_path(["octocat", "Hello-World", "issues", "123"])

      assert PlayGithub.format_path(github_path) ==
               join_lines([
                 "owner: octocat",
                 "repo: Hello-World",
                 "github_url: https://github.com/octocat/Hello-World",
                 "resource: issue",
                 "issue_number: 123",
                 "raw_segments: octocat/Hello-World/issues/123"
               ])
    end

    test "rejects invalid paths" do
      assert PlayGithub.parse_path([]) == {:error, :missing_owner_or_repo}
      assert PlayGithub.parse_path(["octocat"]) == {:error, :missing_owner_or_repo}

      assert PlayGithub.parse_path(["octocat", "Hello-World", "tree"]) ==
               {:error, :missing_tree_ref}

      assert PlayGithub.parse_path(["octocat", "Hello-World", "issues", "nope"]) ==
               {:error, :invalid_issue_number}

      assert PlayGithub.parse_path(["octocat", "Hello-World", "pull", "1"]) ==
               {:error, {:unsupported_github_path, ["pull", "1"]}}
    end
  end

  describe "github_url/1" do
    test "returns github repository URL for parsed repository path" do
      {:ok, github_path} = PlayGithub.parse_path(["octocat", "Hello-World"])

      assert PlayGithub.github_url(github_path) == "https://github.com/octocat/Hello-World"
    end
  end

  describe "sandbox_name/1" do
    test "returns stable Daytona sandbox name for repository URL" do
      {:ok, github_path} = PlayGithub.parse_path(["octocat", "Hello-World"])
      {:ok, other_path} = PlayGithub.parse_path(["octocat", "Spoon-Knife"])

      sandbox_name = PlayGithub.sandbox_name(github_path)

      assert sandbox_name == PlayGithub.sandbox_name(github_path)
      assert sandbox_name != PlayGithub.sandbox_name(other_path)
      assert String.starts_with?(sandbox_name, "playgithub-")
      assert String.length(sandbox_name) == String.length("playgithub-") + 16
    end
  end

  defp join_lines(lines), do: Enum.join(lines, "\n")
end
