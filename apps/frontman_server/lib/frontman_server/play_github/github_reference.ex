# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.GithubReference do
  @moduledoc """
  Parses and formats GitHub-shaped references routed through PlayGithub.
  """

  use TypedStruct

  alias __MODULE__.{IssuePath, RepositoryPath, TreePath}

  @type resource :: RepositoryPath.t() | TreePath.t() | IssuePath.t()

  typedstruct enforce: true do
    field(:owner, String.t())
    field(:repo, String.t())
    field(:resource, resource())
    field(:raw_segments, [String.t()])
  end

  @spec parse_path([String.t()]) ::
          {:ok, t()}
          | {:error, :missing_owner_or_repo}
          | {:error, :missing_tree_ref}
          | {:error, :invalid_issue_number}
          | {:error, {:unsupported_github_path, [String.t()]}}
  def parse_path([owner, repo]) do
    {:ok,
     %__MODULE__{
       owner: owner,
       repo: repo,
       resource: %RepositoryPath{},
       raw_segments: [owner, repo]
     }}
  end

  def parse_path([_owner, _repo, "tree"]) do
    {:error, :missing_tree_ref}
  end

  def parse_path([owner, repo, "tree", ref | path_segments]) do
    {:ok,
     %__MODULE__{
       owner: owner,
       repo: repo,
       resource: %TreePath{ref: ref, path_segments: path_segments},
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
         %__MODULE__{
           owner: owner,
           repo: repo,
           resource: %IssuePath{number: issue_number},
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

  @spec format(t()) :: String.t()
  def format(
        %__MODULE__{
          owner: owner,
          repo: repo,
          resource: resource,
          raw_segments: raw_segments
        } = github_reference
      ) do
    [
      "owner: #{owner}",
      "repo: #{repo}",
      "github_url: #{github_url(github_reference)}",
      format_resource(resource),
      "raw_segments: #{Enum.join(raw_segments, "/")}"
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  @spec github_url(t()) :: String.t()
  def github_url(%__MODULE__{owner: owner, repo: repo}) do
    "https://github.com/#{owner}/#{repo}"
  end

  @spec repository_identity(t()) :: String.t()
  def repository_identity(%__MODULE__{resource: %TreePath{} = tree_path} = github_reference) do
    repo_url = github_url(github_reference)

    case TreePath.repo_path(tree_path) do
      nil -> "#{repo_url}/tree/#{tree_path.ref}"
      repo_path -> "#{repo_url}/tree/#{tree_path.ref}/#{repo_path}"
    end
  end

  def repository_identity(%__MODULE__{} = github_reference) do
    github_url(github_reference)
  end

  defp format_resource(%RepositoryPath{}) do
    "resource: repository"
  end

  defp format_resource(%TreePath{} = tree_path) do
    [
      "resource: tree",
      "ref: #{tree_path.ref}",
      "path: #{format_repo_path(TreePath.repo_path(tree_path))}"
    ]
  end

  defp format_resource(%IssuePath{number: number}) do
    [
      "resource: issue",
      "issue_number: #{number}"
    ]
  end

  defp format_repo_path(nil), do: ""
  defp format_repo_path(repo_path), do: repo_path
end
