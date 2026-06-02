defmodule FrontmanServer.PlayGithub.GithubReferenceTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.PlayGithub.GithubReference

  describe "parse_path/1" do
    test "parses repository paths" do
      assert {:ok, _github_reference} = GithubReference.parse_path(["octocat", "Hello-World"])
    end

    test "parses tree paths" do
      assert {:ok, _github_reference} =
               GithubReference.parse_path([
                 "octocat",
                 "Hello-World",
                 "tree",
                 "main",
                 "apps",
                 "web"
               ])
    end

    test "parses issue paths" do
      assert {:ok, _github_reference} =
               GithubReference.parse_path(["octocat", "Hello-World", "issues", "123"])
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

  describe "repository-backed helpers" do
    test "derive repository execution fields from repository paths" do
      {:ok, github_reference} = GithubReference.parse_path(["octocat", "Hello-World"])

      assert GithubReference.repository_backed?(github_reference)

      assert GithubReference.repository_url(github_reference) ==
               "https://github.com/octocat/Hello-World"

      assert GithubReference.branch(github_reference) == nil
      assert GithubReference.repository_path(github_reference) == nil
      assert GithubReference.workspace_path(github_reference) == "workspace"
    end

    test "derive repository execution fields from tree paths" do
      {:ok, github_reference} =
        GithubReference.parse_path(["octocat", "Hello-World", "tree", "main", "apps", "web"])

      assert GithubReference.repository_backed?(github_reference)
      assert GithubReference.branch(github_reference) == "main"
      assert GithubReference.repository_path(github_reference) == "apps/web"
      assert GithubReference.workspace_path(github_reference) == "workspace/apps/web"
    end

    test "issue paths are not repository-backed" do
      {:ok, github_reference} =
        GithubReference.parse_path(["octocat", "Hello-World", "issues", "123"])

      refute GithubReference.repository_backed?(github_reference)
    end
  end
end
