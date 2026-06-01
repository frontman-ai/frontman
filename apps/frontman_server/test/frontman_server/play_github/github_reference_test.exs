defmodule FrontmanServer.PlayGithub.GithubReferenceTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.PlayGithub.GithubReference

  describe "parse_path/1" do
    test "parses repository paths" do
      assert {:ok, github_reference} = GithubReference.parse_path(["octocat", "Hello-World"])

      assert GithubReference.format(github_reference) ==
               join_lines([
                 "owner: octocat",
                 "repo: Hello-World",
                 "github_url: https://github.com/octocat/Hello-World",
                 "resource: repository",
                 "raw_segments: octocat/Hello-World"
               ])
    end

    test "parses tree paths" do
      assert {:ok, github_reference} =
               GithubReference.parse_path([
                 "octocat",
                 "Hello-World",
                 "tree",
                 "main",
                 "apps",
                 "web"
               ])

      assert GithubReference.format(github_reference) ==
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
      assert {:ok, github_reference} =
               GithubReference.parse_path(["octocat", "Hello-World", "issues", "123"])

      assert GithubReference.format(github_reference) ==
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
      assert GithubReference.parse_path([]) == {:error, :missing_owner_or_repo}
      assert GithubReference.parse_path(["octocat"]) == {:error, :missing_owner_or_repo}

      assert GithubReference.parse_path(["octocat", "Hello-World", "tree"]) ==
               {:error, :missing_tree_ref}

      assert GithubReference.parse_path(["octocat", "Hello-World", "issues", "nope"]) ==
               {:error, :invalid_issue_number}

      assert GithubReference.parse_path(["octocat", "Hello-World", "pull", "1"]) ==
               {:error, {:unsupported_github_path, ["pull", "1"]}}
    end
  end

  describe "github_url/1" do
    test "returns github repository URL for parsed repository path" do
      {:ok, github_reference} = GithubReference.parse_path(["octocat", "Hello-World"])

      assert GithubReference.github_url(github_reference) ==
               "https://github.com/octocat/Hello-World"
    end
  end

  defp join_lines(lines), do: Enum.join(lines, "\n")
end
