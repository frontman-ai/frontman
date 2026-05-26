# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub do
  @moduledoc """
  Parses GitHub-shaped paths routed through the local PlayGithub host.
  """

  alias FrontmanServer.PlayGithub.{
    GithubIssuePath,
    GithubPath,
    GithubRepositoryPath,
    GithubTreePath
  }

  @spec parse_path([String.t()]) ::
          {:ok, GithubPath.t()}
          | {:error, :missing_owner_or_repo}
          | {:error, :missing_tree_ref}
          | {:error, :invalid_issue_number}
          | {:error, {:unsupported_github_path, [String.t()]}}
  def parse_path([owner, repo]) do
    {:ok,
     %GithubPath{
       owner: owner,
       repo: repo,
       resource: %GithubRepositoryPath{},
       raw_segments: [owner, repo]
     }}
  end

  def parse_path([_owner, _repo, "tree"]) do
    {:error, :missing_tree_ref}
  end

  def parse_path([owner, repo, "tree", ref | path_segments]) do
    {:ok,
     %GithubPath{
       owner: owner,
       repo: repo,
       resource: %GithubTreePath{ref: ref, path_segments: path_segments},
       raw_segments: [owner, repo, "tree", ref | path_segments]
     }}
  end

  def parse_path([_owner, _repo, "issues"]) do
    {:error, :invalid_issue_number}
  end

  def parse_path([owner, repo, "issues", number]) do
    case Integer.parse(number) do
      {issue_number, ""} when issue_number > 0 ->
        {:ok,
         %GithubPath{
           owner: owner,
           repo: repo,
           resource: %GithubIssuePath{number: issue_number},
           raw_segments: [owner, repo, "issues", number]
         }}

      _ ->
        {:error, :invalid_issue_number}
    end
  end

  def parse_path([_owner, _repo, "issues", _number | _extra_segments]) do
    {:error, :invalid_issue_number}
  end

  def parse_path([_owner]), do: {:error, :missing_owner_or_repo}
  def parse_path([]), do: {:error, :missing_owner_or_repo}

  def parse_path([_owner, _repo | extra_segments]) do
    {:error, {:unsupported_github_path, extra_segments}}
  end

  @spec format_path(GithubPath.t()) :: String.t()
  def format_path(%GithubPath{
        owner: owner,
        repo: repo,
        resource: resource,
        raw_segments: raw_segments
      }) do
    [
      "owner: #{owner}",
      "repo: #{repo}",
      format_resource(resource),
      "raw_segments: #{Enum.join(raw_segments, "/")}"
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp format_resource(%GithubRepositoryPath{}) do
    "resource: repository"
  end

  defp format_resource(%GithubTreePath{} = tree_path) do
    [
      "resource: tree",
      "ref: #{tree_path.ref}",
      "path: #{format_repo_path(GithubTreePath.repo_path(tree_path))}"
    ]
  end

  defp format_resource(%GithubIssuePath{number: number}) do
    [
      "resource: issue",
      "issue_number: #{number}"
    ]
  end

  defp format_repo_path(nil), do: ""
  defp format_repo_path(repo_path), do: repo_path
end
