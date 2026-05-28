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
  @frontman_install_state_label "frontman.playgithub.frontman_install_state"
  @frontman_install_command "npx astro add @frontman-ai/astro --yes"
  @frontman_install_timeout_seconds 300

  @type repository_command :: :create | :clone | :install

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

  @spec run_repository_command(GithubPath.t(), repository_command()) ::
          {:ok,
           %{
             command: String.t(),
             repo_url: String.t(),
             clone_state: String.t(),
             frontman_install_state: String.t(),
             sandbox_id: String.t(),
             sandbox_name: String.t(),
             sandbox_reused: boolean(),
             sandbox_state: String.t()
           }}
          | {:error, :not_repository_path}
          | {:error, :daytona_sandbox_not_found}
          | {:error, :repository_not_cloned}
          | {:error, :malformed_daytona_response, term()}
          | {:error, :daytona_create_failed, non_neg_integer(), term()}
          | {:error, :daytona_clone_failed, non_neg_integer(), term()}
          | {:error, :daytona_frontman_install_failed, non_neg_integer(), term()}
          | {:error, :daytona_frontman_install_failed, term()}
          | {:error, :daytona_get_failed, non_neg_integer(), term()}
          | {:error, :daytona_label_failed, non_neg_integer(), term()}
          | {:error, :daytona_repo_label_mismatch, term()}
          | {:error, term()}
  def run_repository_command(
        %GithubPath{resource: %GithubRepositoryPath{}} = github_path,
        command
      )
      when command in [:create, :clone, :install] do
    repo_url = github_url(github_path)
    sandbox_name = sandbox_name(github_path)

    case command do
      :create -> create_repository_sandbox(repo_url, sandbox_name)
      :clone -> clone_repository_sandbox(repo_url, sandbox_name)
      :install -> install_repository_sandbox(repo_url, sandbox_name)
    end
  end

  def run_repository_command(%GithubPath{}, command)
      when command in [:create, :clone, :install] do
    {:error, :not_repository_path}
  end

  defp create_repository_sandbox(repo_url, sandbox_name) do
    case get_repository_sandbox(repo_url, sandbox_name) do
      {:ok, sandbox} ->
        {:ok,
         repository_sandbox(
           "create",
           repo_url,
           clone_state_from_labels(sandbox.labels),
           frontman_install_state_from_labels(sandbox.labels),
           sandbox.id,
           sandbox_name,
           true,
           sandbox.state
         )}

      {:error, :daytona_sandbox_not_found} ->
        create_named_repository_sandbox(repo_url, sandbox_name)

      {:error, reason, status, body} ->
        {:error, reason, status, body}

      {:error, reason, body} ->
        {:error, reason, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp clone_repository_sandbox(repo_url, sandbox_name) do
    case get_repository_sandbox(repo_url, sandbox_name) do
      {:ok, sandbox} ->
        clone_existing_repository_sandbox(repo_url, sandbox_name, sandbox)

      {:error, reason, status, body} ->
        {:error, reason, status, body}

      {:error, reason, body} ->
        {:error, reason, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp install_repository_sandbox(repo_url, sandbox_name) do
    case get_repository_sandbox(repo_url, sandbox_name) do
      {:ok, sandbox} ->
        install_existing_repository_sandbox(repo_url, sandbox_name, sandbox)

      {:error, reason, status, body} ->
        {:error, reason, status, body}

      {:error, reason, body} ->
        {:error, reason, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_repository_sandbox(repo_url, sandbox_name) do
    case Daytona.get_sandbox(sandbox_name) do
      {:ok, %Req.Response{status: status, body: %{"id" => id, "state" => state} = body}}
      when status in 200..299 ->
        labels = Map.get(body, "labels", %{})

        case labels do
          %{@repo_url_label => ^repo_url} ->
            {:ok, %{id: id, state: state, labels: labels}}

          _ ->
            {:error, :daytona_repo_label_mismatch, labels}
        end

      {:ok, %Req.Response{status: 404}} ->
        {:error, :daytona_sandbox_not_found}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_get_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
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
           Daytona.clone_repository(sandbox_id, repo_url),
         :ok <- mark_repository_cloned(repo_url, sandbox_id) do
      finish_frontman_install(
        repo_url,
        sandbox_id,
        sandbox_name,
        sandbox_reused,
        "started",
        "cloned",
        %{}
      )
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
       frontman_install_state: "waiting_for_clone",
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

  defp mark_repository_cloned(repo_url, sandbox_id) do
    labels = %{
      @repo_url_label => repo_url,
      @repo_cloned_label => "true",
      @clone_state_label => "cloned"
    }

    case Daytona.replace_labels(sandbox_id, labels) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

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

  defp finish_frontman_install(
         repo_url,
         sandbox_id,
         sandbox_name,
         sandbox_reused,
         sandbox_state,
         clone_state,
         labels
       ) do
    case Map.get(labels, @frontman_install_state_label) do
      state when state in ["installed", "installing", "install_failed"] ->
        {:ok,
         repository_sandbox(
           repo_url,
           clone_state,
           state,
           sandbox_id,
           sandbox_name,
           sandbox_reused,
           sandbox_state
         )}

      _ ->
        install_frontman(
          repo_url,
          sandbox_id,
          sandbox_name,
          sandbox_reused,
          sandbox_state,
          clone_state
        )
    end
  end

  defp install_frontman(
         repo_url,
         sandbox_id,
         sandbox_name,
         sandbox_reused,
         sandbox_state,
         clone_state
       ) do
    with :ok <- mark_frontman_installing(repo_url, sandbox_id),
         {:ok, %Req.Response{status: status, body: %{"exitCode" => 0}}}
         when status in 200..299 <-
           Daytona.execute_command(
             sandbox_id,
             @frontman_install_command,
             cwd: "workspace",
             timeout_seconds: @frontman_install_timeout_seconds
           ),
         :ok <- mark_frontman_installed(repo_url, sandbox_id) do
      {:ok,
       repository_sandbox(
         repo_url,
         clone_state,
         "installed",
         sandbox_id,
         sandbox_name,
         sandbox_reused,
         sandbox_state
       )}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        mark_frontman_install_failed(repo_url, sandbox_id)
        {:error, :daytona_frontman_install_failed, status, body}

      {:error, :daytona_label_failed, status, body} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        mark_frontman_install_failed(repo_url, sandbox_id)
        {:error, :daytona_frontman_install_failed, reason}
    end
  end

  defp mark_frontman_installing(repo_url, sandbox_id) do
    replace_frontman_install_labels(repo_url, sandbox_id, "installing")
  end

  defp mark_frontman_installed(repo_url, sandbox_id) do
    replace_frontman_install_labels(repo_url, sandbox_id, "installed")
  end

  defp mark_frontman_install_failed(repo_url, sandbox_id) do
    replace_frontman_install_labels(repo_url, sandbox_id, "install_failed")
  end

  defp replace_frontman_install_labels(repo_url, sandbox_id, frontman_install_state) do
    labels = %{
      @repo_url_label => repo_url,
      @repo_cloned_label => "true",
      @clone_state_label => "cloned",
      @frontman_install_state_label => frontman_install_state
    }

    case Daytona.replace_labels(sandbox_id, labels) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp repository_sandbox(
         repo_url,
         clone_state,
         frontman_install_state,
         sandbox_id,
         sandbox_name,
         sandbox_reused,
         sandbox_state
       ) do
    %{
      repo_url: repo_url,
      clone_state: clone_state,
      frontman_install_state: frontman_install_state,
      sandbox_id: sandbox_id,
      sandbox_name: sandbox_name,
      sandbox_reused: sandbox_reused,
      sandbox_state: sandbox_state
    }
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
