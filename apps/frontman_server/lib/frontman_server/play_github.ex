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
    Daytona,
    GithubIssuePath,
    GithubPath,
    GithubRepositoryPath,
    GithubTreePath
  }

  @repo_url_label "frontman.playgithub.repo_url"
  @repo_cloned_label "frontman.playgithub.cloned"
  @clone_state_label "frontman.playgithub.clone_state"

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
  def format_path(
        %GithubPath{
          owner: owner,
          repo: repo,
          resource: resource,
          raw_segments: raw_segments
        } = github_path
      ) do
    [
      "owner: #{owner}",
      "repo: #{repo}",
      "github_url: #{github_url(github_path)}",
      format_resource(resource),
      "raw_segments: #{Enum.join(raw_segments, "/")}"
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  @spec github_url(GithubPath.t()) :: String.t()
  def github_url(%GithubPath{owner: owner, repo: repo}) do
    "https://github.com/#{owner}/#{repo}"
  end

  @spec sandbox_name(GithubPath.t()) :: String.t()
  def sandbox_name(%GithubPath{} = github_path) do
    github_path
    |> github_url()
    |> sandbox_name_for_repo_url()
  end

  @spec get_or_create_repository_sandbox(GithubPath.t()) ::
          {:ok,
           %{
             repo_url: String.t(),
             clone_state: String.t(),
             sandbox_id: String.t(),
             sandbox_name: String.t(),
             sandbox_reused: boolean(),
             sandbox_state: String.t()
           }}
          | {:error, :not_repository_path}
          | {:error, :malformed_daytona_response, term()}
          | {:error, :daytona_create_failed, non_neg_integer(), term()}
          | {:error, :daytona_clone_failed, non_neg_integer(), term()}
          | {:error, :daytona_get_failed, non_neg_integer(), term()}
          | {:error, :daytona_label_failed, non_neg_integer(), term()}
          | {:error, :daytona_repo_label_mismatch, term()}
          | {:error, term()}
  def get_or_create_repository_sandbox(
        %GithubPath{resource: %GithubRepositoryPath{}} = github_path
      ) do
    repo_url = github_url(github_path)
    sandbox_name = sandbox_name(github_path)

    case Daytona.get_sandbox(sandbox_name) do
      {:ok, %Req.Response{status: status, body: %{"id" => id, "state" => state} = body}}
      when status in 200..299 ->
        labels = Map.get(body, "labels", %{})

        case labels do
          %{@repo_url_label => ^repo_url, @clone_state_label => "cloning"} ->
            {:ok,
             %{
               repo_url: repo_url,
               clone_state: "cloning",
               sandbox_id: id,
               sandbox_name: sandbox_name,
               sandbox_reused: true,
               sandbox_state: state
             }}

          %{@repo_url_label => ^repo_url, @repo_cloned_label => "true"} ->
            {:ok,
             %{
               repo_url: repo_url,
               clone_state: "already_cloned",
               sandbox_id: id,
               sandbox_name: sandbox_name,
               sandbox_reused: true,
               sandbox_state: state
             }}

          %{@repo_url_label => ^repo_url} ->
            finish_repository_sandbox(repo_url, id, sandbox_name, true, state)

          _ ->
            {:error, :daytona_repo_label_mismatch, labels}
        end

      {:ok, %Req.Response{status: 404}} ->
        create_named_repository_sandbox(repo_url, sandbox_name)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_get_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_or_create_repository_sandbox(%GithubPath{}) do
    {:error, :not_repository_path}
  end

  defp create_named_repository_sandbox(repo_url, sandbox_name) do
    case Daytona.create_sandbox(%{
           name: sandbox_name,
           labels: %{@repo_url_label => repo_url}
         }) do
      {:ok, %Req.Response{status: status, body: %{"id" => id, "state" => state}}}
      when status in 200..299 ->
        finish_repository_sandbox(repo_url, id, sandbox_name, false, state)

      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:error, :malformed_daytona_response, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_create_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp finish_repository_sandbox(repo_url, sandbox_id, sandbox_name, sandbox_reused, "started") do
    with :ok <- mark_repository_cloning(repo_url, sandbox_id),
         {:ok, %Req.Response{status: status}} when status in 200..299 <-
           Daytona.clone_repository(sandbox_id, repo_url) do
      mark_repository_cloned(repo_url, sandbox_id, sandbox_name, sandbox_reused)
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        mark_repository_clone_failed(repo_url, sandbox_id)
        {:error, :daytona_clone_failed, status, body}

      {:error, :daytona_label_failed, status, body} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        mark_repository_clone_failed(repo_url, sandbox_id)
        {:error, reason}
    end
  end

  defp finish_repository_sandbox(
         repo_url,
         sandbox_id,
         sandbox_name,
         sandbox_reused,
         sandbox_state
       ) do
    {:ok,
     %{
       repo_url: repo_url,
       clone_state: "waiting_for_started",
       sandbox_id: sandbox_id,
       sandbox_name: sandbox_name,
       sandbox_reused: sandbox_reused,
       sandbox_state: sandbox_state
     }}
  end

  defp mark_repository_cloning(repo_url, sandbox_id) do
    labels = %{@repo_url_label => repo_url, @clone_state_label => "cloning"}

    case Daytona.replace_labels(sandbox_id, labels) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp mark_repository_cloned(repo_url, sandbox_id, sandbox_name, sandbox_reused) do
    labels = %{
      @repo_url_label => repo_url,
      @repo_cloned_label => "true",
      @clone_state_label => "cloned"
    }

    case Daytona.replace_labels(sandbox_id, labels) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok,
         %{
           repo_url: repo_url,
           clone_state: "cloned",
           sandbox_id: sandbox_id,
           sandbox_name: sandbox_name,
           sandbox_reused: sandbox_reused,
           sandbox_state: "started"
         }}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp mark_repository_clone_failed(repo_url, sandbox_id) do
    Daytona.replace_labels(sandbox_id, %{
      @repo_url_label => repo_url,
      @clone_state_label => "failed"
    })
  end

  defp sandbox_name_for_repo_url(repo_url) do
    hash =
      :sha256
      |> :crypto.hash(repo_url)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    "playgithub-#{hash}"
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
