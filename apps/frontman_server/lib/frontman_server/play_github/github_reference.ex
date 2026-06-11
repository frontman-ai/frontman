# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.GithubReference do
  @moduledoc """
  Parses and formats GitHub-shaped references routed through PlayGithub.
  """

  alias __MODULE__.{IssuePath, RepositoryPath, TreePath}

  @resource_schema Zoi.union([
                     Zoi.struct(RepositoryPath),
                     Zoi.struct(TreePath),
                     Zoi.struct(IssuePath)
                   ])

  @schema Zoi.struct(__MODULE__, %{
            owner: Zoi.string(),
            repo: Zoi.string(),
            resource: @resource_schema,
            raw_segments: Zoi.array(Zoi.string())
          })

  @type resource :: unquote(Zoi.type_spec(@resource_schema))
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

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

  @spec github_url(t()) :: String.t()
  def github_url(%__MODULE__{resource: %TreePath{} = tree_path} = github_reference) do
    repo_url = repository_url(github_reference)

    case TreePath.repo_path(tree_path) do
      nil -> "#{repo_url}/tree/#{tree_path.ref}"
      repo_path -> "#{repo_url}/tree/#{tree_path.ref}/#{repo_path}"
    end
  end

  def github_url(%__MODULE__{resource: %IssuePath{number: number}} = github_reference) do
    "#{repository_url(github_reference)}/issues/#{number}"
  end

  def github_url(%__MODULE__{} = github_reference), do: repository_url(github_reference)

  @spec repository_backed?(t()) :: boolean()
  def repository_backed?(%__MODULE__{resource: %RepositoryPath{}}), do: true
  def repository_backed?(%__MODULE__{resource: %TreePath{}}), do: true
  def repository_backed?(%__MODULE__{}), do: false

  @spec repository_url(t()) :: String.t()
  def repository_url(%__MODULE__{owner: owner, repo: repo}) do
    "https://github.com/#{owner}/#{repo}"
  end

  @spec branch(t()) :: String.t() | nil
  def branch(%__MODULE__{resource: %TreePath{ref: ref}}), do: ref
  def branch(%__MODULE__{}), do: nil

  @spec repository_path(t()) :: String.t() | nil
  def repository_path(%__MODULE__{resource: %TreePath{} = tree_path}) do
    TreePath.repo_path(tree_path)
  end

  def repository_path(%__MODULE__{}), do: nil

  @spec workspace_path(t()) :: String.t()
  def workspace_path(%__MODULE__{} = github_reference) do
    case repository_path(github_reference) do
      nil -> "workspace"
      repository_path -> "workspace/#{repository_path}"
    end
  end

  @spec repository_identity(t()) :: String.t()
  def repository_identity(%__MODULE__{} = github_reference) do
    github_url(github_reference)
  end
end
