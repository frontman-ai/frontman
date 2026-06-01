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
  @clone_started_at_label "frontman.playgithub.clone_started_at"
  @frontman_install_state_label "frontman.playgithub.frontman_install_state"
  @frontman_install_started_at_label "frontman.playgithub.frontman_install_started_at"
  @frontman_install_error_label "frontman.playgithub.frontman_install_error"
  @dev_server_state_label "frontman.playgithub.dev_server_state"
  @dev_server_started_at_label "frontman.playgithub.dev_server_started_at"
  @dev_server_port_label "frontman.playgithub.dev_server_port"
  @dev_server_url_label "frontman.playgithub.dev_server_url"
  @dev_server_error_label "frontman.playgithub.dev_server_error"
  @repository_clone_timeout_seconds 300
  @repository_clone_stale_after_seconds 600
  @frontman_install_command "npx astro add @frontman-ai/astro --yes"
  @frontman_install_log_path "/tmp/frontman-install.log"
  @dev_server_log_path "/tmp/frontman-dev-server.log"
  @dev_server_pid_path "/tmp/frontman-dev-server.pid"
  @dev_server_port 4321
  @dev_server_start_timeout_seconds 10
  @dev_server_preview_expires_seconds 3_600
  @dependency_install_timeout_seconds 600
  @frontman_install_timeout_seconds 300
  @frontman_install_stale_after_seconds 600
  @failure_reason_max_length 1_000
  @sandbox_start_poll_attempts 60
  @sandbox_start_poll_interval_ms 1_000
  @startable_sandbox_states ~w(stopped archived)
  @task_supervisor FrontmanServer.PlayGithub.TaskSupervisor

  @type repository_command :: :create | :start | :clone | :install | :dev

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
    |> sandbox_identity()
    |> sandbox_name_for_identity()
  end

  @spec run_repository_command(GithubPath.t(), repository_command(), keyword()) ::
          {:ok,
           %{
             command: String.t(),
             repo_url: String.t(),
             github_ref: String.t() | nil,
             repo_path: String.t() | nil,
             workspace_path: String.t(),
             clone_state: String.t(),
             frontman_install_state: String.t(),
             frontman_install_error: String.t() | nil,
             frontman_install_log_path: String.t(),
             dev_server_state: String.t() | nil,
             dev_server_port: integer() | nil,
             dev_server_url: String.t() | nil,
             dev_server_url_expires_in_seconds: integer() | nil,
             dev_server_log_path: String.t() | nil,
             dev_server_error: String.t() | nil,
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
          | {:error, :daytona_start_failed, non_neg_integer(), term()}
          | {:error, :daytona_clone_failed, non_neg_integer(), term()}
          | {:error, :daytona_frontman_install_failed, non_neg_integer(), term()}
          | {:error, :daytona_frontman_install_failed, term()}
          | {:error, :daytona_dev_server_failed, non_neg_integer(), term()}
          | {:error, :daytona_preview_url_failed, non_neg_integer(), term()}
          | {:error, :daytona_get_failed, non_neg_integer(), term()}
          | {:error, :daytona_label_failed, non_neg_integer(), term()}
          | {:error, :daytona_repo_label_mismatch, term()}
          | {:error, term()}
  def run_repository_command(github_path, command, opts \\ [])

  def run_repository_command(
        %GithubPath{resource: %GithubRepositoryPath{}} = github_path,
        command,
        opts
      )
      when command in [:create, :start, :clone, :install, :dev] do
    run_repository_target_command(repository_target(github_path), command, opts)
  end

  def run_repository_command(
        %GithubPath{resource: %GithubTreePath{}} = github_path,
        command,
        opts
      )
      when command in [:create, :start, :clone, :install, :dev] do
    run_repository_target_command(repository_target(github_path), command, opts)
  end

  def run_repository_command(%GithubPath{}, command, _opts)
      when command in [:create, :start, :clone, :install, :dev] do
    {:error, :not_repository_path}
  end

  defp run_repository_target_command(target, command, opts) do
    result =
      case command do
        :create -> create_repository_sandbox(target.repo_url, target.sandbox_name)
        :start -> start_repository_sandbox(target.repo_url, target.sandbox_name)
        :clone -> clone_repository_sandbox(target)
        :install -> install_repository_sandbox(target, opts)
        :dev -> start_dev_server_sandbox(target)
      end

    case result do
      {:ok, response} -> {:ok, put_repository_target(response, target)}
      error -> error
    end
  end

  defp put_repository_target(response, target) do
    Map.merge(response, %{
      github_ref: target.github_ref,
      repo_path: target.repo_path,
      workspace_path: target.workspace_path
    })
  end

  defp repository_target(%GithubPath{} = github_path) do
    repo_url = github_url(github_path)

    github_path
    |> resource_target()
    |> Map.merge(%{
      repo_url: repo_url,
      sandbox_name: sandbox_name_for_identity(sandbox_identity(github_path))
    })
  end

  defp sandbox_identity(%GithubPath{resource: %GithubTreePath{} = tree_path} = github_path) do
    repo_url = github_url(github_path)

    case GithubTreePath.repo_path(tree_path) do
      nil -> "#{repo_url}/tree/#{tree_path.ref}"
      repo_path -> "#{repo_url}/tree/#{tree_path.ref}/#{repo_path}"
    end
  end

  defp sandbox_identity(%GithubPath{} = github_path) do
    github_url(github_path)
  end

  defp resource_target(%GithubPath{resource: %GithubRepositoryPath{}}) do
    %{github_ref: nil, repo_path: nil, workspace_path: "workspace"}
  end

  defp resource_target(%GithubPath{resource: %GithubTreePath{} = tree_path}) do
    repo_path = GithubTreePath.repo_path(tree_path)

    %{
      github_ref: tree_path.ref,
      repo_path: repo_path,
      workspace_path: workspace_path(repo_path)
    }
  end

  defp workspace_path(nil), do: "workspace"
  defp workspace_path(repo_path), do: "workspace/#{repo_path}"

  defp create_repository_sandbox(repo_url, sandbox_name) do
    case get_repository_sandbox(repo_url, sandbox_name) do
      {:ok, sandbox} ->
        {:ok,
         repository_sandbox(
           "create",
           repo_url,
           clone_state_for_sandbox(sandbox.labels, sandbox.state),
           frontman_install_state_for_sandbox(sandbox.labels, sandbox.state),
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

  defp clone_repository_sandbox(target) do
    case get_repository_sandbox(target.repo_url, target.sandbox_name) do
      {:ok, sandbox} ->
        clone_existing_repository_sandbox(target, sandbox)

      {:error, reason, status, body} ->
        {:error, reason, status, body}

      {:error, reason, body} ->
        {:error, reason, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_repository_sandbox(repo_url, sandbox_name) do
    case get_repository_sandbox(repo_url, sandbox_name) do
      {:ok, sandbox} ->
        start_existing_repository_sandbox(repo_url, sandbox_name, sandbox)

      {:error, reason, status, body} ->
        {:error, reason, status, body}

      {:error, reason, body} ->
        {:error, reason, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp install_repository_sandbox(target, opts) do
    case get_repository_sandbox(target.repo_url, target.sandbox_name) do
      {:ok, sandbox} ->
        install_existing_repository_sandbox(target, sandbox, opts)

      {:error, reason, status, body} ->
        {:error, reason, status, body}

      {:error, reason, body} ->
        {:error, reason, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_dev_server_sandbox(target) do
    case get_repository_sandbox(target.repo_url, target.sandbox_name) do
      {:ok, sandbox} ->
        start_existing_dev_server_sandbox(target, sandbox)

      {:error, reason, status, body} ->
        {:error, reason, status, body}

      {:error, reason, body} ->
        {:error, reason, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_existing_repository_sandbox(repo_url, sandbox_name, sandbox) do
    case sandbox.state do
      "started" ->
        {:ok, repository_sandbox_for_existing("start", repo_url, sandbox_name, sandbox)}

      "starting" ->
        {:ok, repository_sandbox_for_existing("start", repo_url, sandbox_name, sandbox)}

      sandbox_state when sandbox_state in @startable_sandbox_states ->
        start_daytona_sandbox(repo_url, sandbox_name, sandbox)

      _sandbox_state ->
        {:ok, repository_sandbox_for_existing("start", repo_url, sandbox_name, sandbox)}
    end
  end

  defp start_daytona_sandbox(repo_url, sandbox_name, sandbox) do
    case Daytona.start_sandbox(sandbox.id) do
      {:ok, %Req.Response{status: status, body: %{"state" => state}}} when status in 200..299 ->
        {:ok,
         repository_sandbox_for_existing("start", repo_url, sandbox_name, %{
           sandbox
           | state: state
         })}

      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok,
         repository_sandbox_for_existing("start", repo_url, sandbox_name, %{
           sandbox
           | state: "starting"
         })}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_start_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp repository_sandbox_for_existing(command, repo_url, sandbox_name, sandbox) do
    command
    |> repository_sandbox(
      repo_url,
      clone_state_for_sandbox(sandbox.labels, sandbox.state),
      frontman_install_state_for_sandbox(sandbox.labels, sandbox.state),
      sandbox.id,
      sandbox_name,
      true,
      sandbox.state
    )
    |> Map.put(:frontman_install_error, Map.get(sandbox.labels, @frontman_install_error_label))
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
        {:ok,
         repository_sandbox(
           "create",
           repo_url,
           "not_started",
           "not_started",
           id,
           sandbox_name,
           false,
           state
         )}

      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:error, :malformed_daytona_response, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_create_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp clone_existing_repository_sandbox(target, sandbox) do
    case {Map.get(sandbox.labels, @clone_state_label),
          Map.get(sandbox.labels, @repo_cloned_label), sandbox.state} do
      {_clone_state, "true", _sandbox_state} ->
        {:ok,
         repository_sandbox(
           "clone",
           target.repo_url,
           "already_cloned",
           frontman_install_state_for_sandbox(sandbox.labels, sandbox.state),
           sandbox.id,
           target.sandbox_name,
           true,
           sandbox.state
         )}

      {"cloning", _cloned, "started"} ->
        case repository_clone_stale?(sandbox.labels) do
          true ->
            clone_started_repository_sandbox(target, sandbox.id, true)

          false ->
            {:ok,
             repository_sandbox(
               "clone",
               target.repo_url,
               "cloning",
               "waiting_for_clone",
               sandbox.id,
               target.sandbox_name,
               true,
               sandbox.state
             )}
        end

      {_clone_state, _cloned, "starting"} ->
        {:ok,
         repository_sandbox(
           "clone",
           target.repo_url,
           "waiting_for_started",
           "waiting_for_clone",
           sandbox.id,
           target.sandbox_name,
           true,
           sandbox.state
         )}

      {_clone_state, _cloned, "started"} ->
        clone_started_repository_sandbox(target, sandbox.id, true)

      {_clone_state, _cloned, sandbox_state} when sandbox_state in @startable_sandbox_states ->
        start_sandbox_then_clone_repository(target, sandbox.id, true)

      {_clone_state, _cloned, _sandbox_state} ->
        {:ok,
         repository_sandbox(
           "clone",
           target.repo_url,
           "waiting_for_started",
           frontman_install_state_for_clone_state("waiting_for_started"),
           sandbox.id,
           target.sandbox_name,
           true,
           sandbox.state
         )}
    end
  end

  defp clone_started_repository_sandbox(target, sandbox_id, sandbox_reused) do
    with :ok <- mark_repository_cloning(target.repo_url, sandbox_id),
         {:ok, _pid} <-
           start_background_job(fn -> clone_repository_in_background(target, sandbox_id) end) do
      {:ok,
       repository_sandbox(
         "clone",
         target.repo_url,
         "cloning",
         "waiting_for_clone",
         sandbox_id,
         target.sandbox_name,
         sandbox_reused,
         "started"
       )}
    else
      {:error, :daytona_label_failed, status, body} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        mark_repository_clone_failed(target.repo_url, sandbox_id)
        {:error, reason}
    end
  end

  defp start_sandbox_then_clone_repository(target, sandbox_id, sandbox_reused) do
    with :ok <- mark_repository_waiting_for_started(target.repo_url, sandbox_id),
         {:ok, _pid} <-
           start_background_job(fn ->
             start_sandbox_then_clone_in_background(target, sandbox_id)
           end) do
      {:ok,
       repository_sandbox(
         "clone",
         target.repo_url,
         "waiting_for_started",
         "waiting_for_clone",
         sandbox_id,
         target.sandbox_name,
         sandbox_reused,
         "starting"
       )}
    else
      {:error, :daytona_label_failed, status, body} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        mark_repository_clone_failed(target.repo_url, sandbox_id)
        {:error, reason}
    end
  end

  defp start_sandbox_then_clone_in_background(target, sandbox_id) do
    case start_sandbox_until_started(sandbox_id) do
      :ok ->
        mark_repository_cloning(target.repo_url, sandbox_id)
        clone_repository_in_background(target, sandbox_id)

      {:error, _reason} ->
        mark_repository_clone_failed(target.repo_url, sandbox_id)
    end
  end

  defp clone_repository_in_background(target, sandbox_id) do
    case Daytona.execute_command(
           sandbox_id,
           clone_command(target),
           cwd: ".",
           timeout_seconds: @repository_clone_timeout_seconds
         ) do
      {:ok, %Req.Response{status: status, body: %{"exitCode" => 0}}} when status in 200..299 ->
        mark_repository_cloned(target.repo_url, sandbox_id)

      {:ok, %Req.Response{}} ->
        mark_repository_clone_failed(target.repo_url, sandbox_id)

      {:error, _reason} ->
        mark_repository_clone_failed(target.repo_url, sandbox_id)
    end
  end

  defp mark_repository_cloning(repo_url, sandbox_id) do
    labels = %{
      @repo_url_label => repo_url,
      @clone_state_label => "cloning",
      @clone_started_at_label => System.system_time(:second) |> Integer.to_string()
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

  defp mark_repository_waiting_for_started(repo_url, sandbox_id) do
    labels = %{@repo_url_label => repo_url, @clone_state_label => "waiting_for_started"}

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

  defp install_existing_repository_sandbox(target, sandbox, opts) do
    case {Map.get(sandbox.labels, @repo_cloned_label),
          Map.get(sandbox.labels, @clone_state_label)} do
      {"true", _clone_state} ->
        install_cloned_repository_sandbox(target, sandbox, opts)

      {_cloned, "cloning"} ->
        install_waiting_for_clone(target, sandbox)

      {_cloned, _clone_state} ->
        {:error, :repository_not_cloned}
    end
  end

  defp install_cloned_repository_sandbox(target, sandbox, opts) do
    case {Map.get(sandbox.labels, @frontman_install_state_label), sandbox.state, retry?(opts)} do
      {"installed", _sandbox_state, _retry} ->
        installed_repository_sandbox(target, sandbox, "installed")

      {"install_failed", "started", true} ->
        install_frontman(target, sandbox.id, true, sandbox.state)

      {"install_failed", sandbox_state, true} when sandbox_state in @startable_sandbox_states ->
        start_sandbox_then_install_frontman(target, sandbox.id, true)

      {"install_failed", _sandbox_state, _retry} ->
        installed_repository_sandbox(target, sandbox, "install_failed")

      {"installing", "started", _retry} ->
        install_started_repository_sandbox(target, sandbox)

      {_frontman_install_state, "started", _retry} ->
        install_frontman(target, sandbox.id, true, sandbox.state)

      {_frontman_install_state, sandbox_state, _retry}
      when sandbox_state in @startable_sandbox_states ->
        start_sandbox_then_install_frontman(target, sandbox.id, true)

      {_frontman_install_state, _sandbox_state, _retry} ->
        installed_repository_sandbox(target, sandbox, "waiting_for_started")
    end
  end

  defp retry?(opts), do: Keyword.get(opts, :retry, false)

  defp install_started_repository_sandbox(target, sandbox) do
    case frontman_install_stale?(sandbox.labels) do
      true ->
        install_frontman(target, sandbox.id, true, sandbox.state)

      false ->
        installed_repository_sandbox(target, sandbox, "installing")
    end
  end

  defp installed_repository_sandbox(target, sandbox, frontman_install_state) do
    {:ok,
     "install"
     |> repository_sandbox(
       target.repo_url,
       clone_state_for_sandbox(sandbox.labels, sandbox.state),
       frontman_install_state,
       sandbox.id,
       target.sandbox_name,
       true,
       sandbox.state
     )
     |> Map.put(:frontman_install_error, Map.get(sandbox.labels, @frontman_install_error_label))}
  end

  defp install_waiting_for_clone(target, sandbox) do
    clone_state =
      case sandbox.state do
        "started" -> "cloning"
        _sandbox_state -> "waiting_for_started"
      end

    {:ok,
     repository_sandbox(
       "install",
       target.repo_url,
       clone_state,
       "waiting_for_clone",
       sandbox.id,
       target.sandbox_name,
       true,
       sandbox.state
     )}
  end

  defp start_existing_dev_server_sandbox(target, sandbox) do
    case {Map.get(sandbox.labels, @repo_cloned_label),
          Map.get(sandbox.labels, @frontman_install_state_label), sandbox.state} do
      {"true", "installed", "started"} ->
        start_dev_server(target, sandbox)

      {"true", "installed", _sandbox_state} ->
        {:ok, dev_server_repository_sandbox(target, sandbox, "waiting_for_started", nil)}

      {"true", _frontman_install_state, _sandbox_state} ->
        {:error, :frontman_not_installed}

      {_cloned, _frontman_install_state, _sandbox_state} ->
        {:error, :repository_not_cloned}
    end
  end

  defp start_dev_server(target, sandbox) do
    with :ok <- run_dev_server_command(target, sandbox.id),
         {:ok, dev_server_url} <- create_dev_server_preview_url(sandbox.id),
         :ok <- mark_dev_server_starting(target.repo_url, sandbox.id, dev_server_url) do
      {:ok, dev_server_repository_sandbox(target, sandbox, "starting", dev_server_url)}
    else
      {:error, :daytona_label_failed, status, body} ->
        {:error, :daytona_label_failed, status, body}

      {:error, :daytona_dev_server_failed, status, body} ->
        mark_dev_server_failed(target.repo_url, sandbox.id, failure_reason(body))
        {:error, :daytona_dev_server_failed, status, body}

      {:error, :daytona_preview_url_failed, status, body} ->
        mark_dev_server_failed(target.repo_url, sandbox.id, failure_reason(body))
        {:error, :daytona_preview_url_failed, status, body}

      {:error, reason, body} ->
        mark_dev_server_failed(target.repo_url, sandbox.id, failure_reason(body))
        {:error, reason, body}

      {:error, reason} ->
        mark_dev_server_failed(target.repo_url, sandbox.id, failure_reason(reason))
        {:error, reason}
    end
  end

  defp run_dev_server_command(target, sandbox_id) do
    case Daytona.execute_command(
           sandbox_id,
           dev_server_command(),
           cwd: target.workspace_path,
           timeout_seconds: @dev_server_start_timeout_seconds
         ) do
      {:ok, %Req.Response{status: status, body: %{"exitCode" => 0}}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_dev_server_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_dev_server_preview_url(sandbox_id) do
    case Daytona.create_signed_preview_url(
           sandbox_id,
           @dev_server_port,
           @dev_server_preview_expires_seconds
         ) do
      {:ok, %Req.Response{status: status, body: %{"url" => url}}} when status in 200..299 ->
        {:ok, url}

      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:error, :malformed_daytona_response, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_preview_url_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dev_server_repository_sandbox(target, sandbox, dev_server_state, dev_server_url) do
    "dev"
    |> repository_sandbox(
      target.repo_url,
      clone_state_for_sandbox(sandbox.labels, sandbox.state),
      frontman_install_state_for_sandbox(sandbox.labels, sandbox.state),
      sandbox.id,
      target.sandbox_name,
      true,
      sandbox.state
    )
    |> Map.put(:frontman_install_error, Map.get(sandbox.labels, @frontman_install_error_label))
    |> Map.put(:dev_server_state, dev_server_state)
    |> Map.put(:dev_server_port, @dev_server_port)
    |> Map.put(:dev_server_url, dev_server_url)
    |> Map.put(:dev_server_url_expires_in_seconds, @dev_server_preview_expires_seconds)
    |> Map.put(:dev_server_log_path, @dev_server_log_path)
    |> Map.put(:dev_server_error, nil)
  end

  defp start_sandbox_then_install_frontman(target, sandbox_id, sandbox_reused) do
    with :ok <- mark_frontman_install_waiting_for_started(target.repo_url, sandbox_id),
         {:ok, _pid} <-
           start_background_job(fn ->
             start_sandbox_then_install_in_background(target, sandbox_id)
           end) do
      {:ok,
       repository_sandbox(
         "install",
         target.repo_url,
         "cloned",
         "waiting_for_started",
         sandbox_id,
         target.sandbox_name,
         sandbox_reused,
         "starting"
       )}
    else
      {:error, :daytona_label_failed, status, body} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        mark_frontman_install_failed(target.repo_url, sandbox_id)
        {:error, :daytona_frontman_install_failed, reason}
    end
  end

  defp start_sandbox_then_install_in_background(target, sandbox_id) do
    case start_sandbox_until_started(sandbox_id) do
      :ok ->
        mark_frontman_installing(target.repo_url, sandbox_id)
        install_frontman_in_background(target, sandbox_id)

      {:error, _reason} ->
        mark_frontman_install_failed(target.repo_url, sandbox_id)
    end
  end

  defp install_frontman(
         target,
         sandbox_id,
         sandbox_reused,
         sandbox_state
       ) do
    with :ok <- mark_frontman_installing(target.repo_url, sandbox_id),
         {:ok, _pid} <-
           start_background_job(fn -> install_frontman_in_background(target, sandbox_id) end) do
      {:ok,
       repository_sandbox(
         "install",
         target.repo_url,
         "cloned",
         "installing",
         sandbox_id,
         target.sandbox_name,
         sandbox_reused,
         sandbox_state
       )}
    else
      {:error, :daytona_label_failed, status, body} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        mark_frontman_install_failed(target.repo_url, sandbox_id)
        {:error, :daytona_frontman_install_failed, reason}
    end
  end

  defp install_frontman_in_background(target, sandbox_id) do
    case ensure_workspace_path_exists(target, sandbox_id) do
      :ok ->
        install_dependencies_then_frontman(target, sandbox_id)

      {:error, reason} ->
        mark_frontman_install_failed(target.repo_url, sandbox_id, reason)
    end
  end

  defp install_dependencies_then_frontman(target, sandbox_id) do
    case run_dependency_install_command(target, sandbox_id) do
      :ok ->
        run_frontman_install_command(target, sandbox_id)

      {:error, reason} ->
        mark_frontman_install_failed(target.repo_url, sandbox_id, reason)
    end
  end

  defp ensure_workspace_path_exists(%{repo_path: nil}, _sandbox_id), do: :ok

  defp ensure_workspace_path_exists(target, sandbox_id) do
    case Daytona.execute_command(
           sandbox_id,
           "test -d #{shell_quote(target.workspace_path)}",
           cwd: ".",
           timeout_seconds: @frontman_install_timeout_seconds
         ) do
      {:ok, %Req.Response{status: status, body: %{"exitCode" => 0}}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{}} ->
        {:error, "Path #{target.workspace_path} does not exist"}

      {:error, _reason} ->
        {:error, "Path #{target.workspace_path} does not exist"}
    end
  end

  defp run_dependency_install_command(target, sandbox_id) do
    case Daytona.execute_command(
           sandbox_id,
           logged_install_command(dependency_install_command(target), "dependency install", true),
           cwd: ".",
           timeout_seconds: @dependency_install_timeout_seconds
         ) do
      {:ok, %Req.Response{status: status, body: %{"exitCode" => 0}}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{body: body}} ->
        {:error, dependency_install_failure_reason(body)}

      {:error, reason} ->
        {:error, dependency_install_failure_reason(reason)}
    end
  end

  defp run_frontman_install_command(target, sandbox_id) do
    case Daytona.execute_command(
           sandbox_id,
           logged_install_command(@frontman_install_command, "frontman install", false),
           cwd: target.workspace_path,
           timeout_seconds: @frontman_install_timeout_seconds
         ) do
      {:ok, %Req.Response{status: status, body: %{"exitCode" => 0}}} when status in 200..299 ->
        mark_frontman_installed(target.repo_url, sandbox_id)

      {:ok, %Req.Response{body: body}} ->
        mark_frontman_install_failed(target.repo_url, sandbox_id, failure_reason(body))

      {:error, reason} ->
        mark_frontman_install_failed(target.repo_url, sandbox_id, failure_reason(reason))
    end
  end

  defp mark_frontman_installing(repo_url, sandbox_id) do
    replace_frontman_install_labels(repo_url, sandbox_id, "installing")
  end

  defp mark_frontman_install_waiting_for_started(repo_url, sandbox_id) do
    replace_frontman_install_labels(repo_url, sandbox_id, "waiting_for_started")
  end

  defp mark_frontman_installed(repo_url, sandbox_id) do
    replace_frontman_install_labels(repo_url, sandbox_id, "installed")
  end

  defp mark_frontman_install_failed(repo_url, sandbox_id) do
    replace_frontman_install_labels(repo_url, sandbox_id, "install_failed")
  end

  defp mark_frontman_install_failed(repo_url, sandbox_id, reason) do
    replace_frontman_install_labels(repo_url, sandbox_id, "install_failed", reason)
  end

  defp replace_frontman_install_labels(repo_url, sandbox_id, frontman_install_state) do
    labels = frontman_install_labels(repo_url, frontman_install_state)

    replace_frontman_install_labels(sandbox_id, labels)
  end

  defp replace_frontman_install_labels(repo_url, sandbox_id, frontman_install_state, error) do
    labels =
      repo_url
      |> frontman_install_labels(frontman_install_state)
      |> maybe_put_frontman_install_error(error)

    replace_frontman_install_labels(sandbox_id, labels)
  end

  defp replace_frontman_install_labels(sandbox_id, labels) do
    case Daytona.replace_labels(sandbox_id, labels) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp frontman_install_labels(repo_url, "installing") do
    repo_url
    |> frontman_install_labels("installing", System.system_time(:second) |> Integer.to_string())
  end

  defp frontman_install_labels(repo_url, frontman_install_state) do
    frontman_install_labels(repo_url, frontman_install_state, nil)
  end

  defp frontman_install_labels(repo_url, frontman_install_state, nil) do
    %{
      @repo_url_label => repo_url,
      @repo_cloned_label => "true",
      @clone_state_label => "cloned",
      @frontman_install_state_label => frontman_install_state
    }
  end

  defp frontman_install_labels(repo_url, frontman_install_state, started_at) do
    repo_url
    |> frontman_install_labels(frontman_install_state, nil)
    |> Map.put(@frontman_install_started_at_label, started_at)
  end

  defp maybe_put_frontman_install_error(labels, nil), do: labels
  defp maybe_put_frontman_install_error(labels, ""), do: labels

  defp maybe_put_frontman_install_error(labels, error) do
    Map.put(labels, @frontman_install_error_label, error)
  end

  defp mark_dev_server_starting(repo_url, sandbox_id, dev_server_url) do
    labels = %{
      @repo_url_label => repo_url,
      @repo_cloned_label => "true",
      @clone_state_label => "cloned",
      @frontman_install_state_label => "installed",
      @dev_server_state_label => "starting",
      @dev_server_started_at_label => System.system_time(:second) |> Integer.to_string(),
      @dev_server_port_label => Integer.to_string(@dev_server_port),
      @dev_server_url_label => dev_server_url
    }

    replace_dev_server_labels(sandbox_id, labels)
  end

  defp mark_dev_server_failed(repo_url, sandbox_id, error) do
    labels = %{
      @repo_url_label => repo_url,
      @repo_cloned_label => "true",
      @clone_state_label => "cloned",
      @frontman_install_state_label => "installed",
      @dev_server_state_label => "failed",
      @dev_server_port_label => Integer.to_string(@dev_server_port),
      @dev_server_error_label => error
    }

    replace_dev_server_labels(sandbox_id, labels)
  end

  defp replace_dev_server_labels(sandbox_id, labels) do
    case Daytona.replace_labels(sandbox_id, labels) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp clone_state_from_labels(labels) do
    case {Map.get(labels, @clone_state_label), Map.get(labels, @repo_cloned_label)} do
      {"cloning", _cloned} -> "cloning"
      {"failed", _cloned} -> "failed"
      {_clone_state, "true"} -> "cloned"
      {clone_state, _cloned} when is_binary(clone_state) -> clone_state
      {_clone_state, _cloned} -> "not_started"
    end
  end

  defp clone_state_for_sandbox(labels, sandbox_state) do
    case {Map.get(labels, @repo_cloned_label), Map.get(labels, @clone_state_label), sandbox_state} do
      {"true", _clone_state, _sandbox_state} -> "cloned"
      {_cloned, "cloning", "started"} -> "cloning"
      {_cloned, "cloning", _sandbox_state} -> "waiting_for_started"
      {_cloned, _clone_state, _sandbox_state} -> clone_state_from_labels(labels)
    end
  end

  defp frontman_install_state_for_sandbox(labels, sandbox_state) do
    clone_state = clone_state_for_sandbox(labels, sandbox_state)

    case Map.get(labels, @frontman_install_state_label) do
      nil -> frontman_install_state_for_clone_state(clone_state)
      frontman_install_state -> frontman_install_state
    end
  end

  defp frontman_install_state_for_clone_state("cloned"), do: "not_started"
  defp frontman_install_state_for_clone_state(_clone_state), do: "waiting_for_clone"

  defp repository_clone_stale?(labels) do
    case labels do
      %{@clone_started_at_label => clone_started_at} ->
        clone_started_at
        |> Integer.parse()
        |> case do
          {seconds, ""} ->
            System.system_time(:second) - seconds > @repository_clone_stale_after_seconds

          _invalid ->
            true
        end

      _labels ->
        true
    end
  end

  defp frontman_install_stale?(labels) do
    case labels do
      %{@frontman_install_started_at_label => install_started_at} ->
        install_started_at
        |> Integer.parse()
        |> case do
          {seconds, ""} ->
            System.system_time(:second) - seconds > @frontman_install_stale_after_seconds

          _invalid ->
            true
        end

      _labels ->
        true
    end
  end

  defp start_sandbox_until_started(sandbox_id) do
    case Daytona.start_sandbox(sandbox_id) do
      {:ok, %Req.Response{status: status, body: %{"state" => "started"}}}
      when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        wait_for_started_sandbox(sandbox_id, @sandbox_start_poll_attempts)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:daytona_start_failed, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp wait_for_started_sandbox(_sandbox_id, 0), do: {:error, :daytona_start_timeout}

  defp wait_for_started_sandbox(sandbox_id, attempts_remaining) do
    Process.sleep(@sandbox_start_poll_interval_ms)

    case Daytona.get_sandbox(sandbox_id) do
      {:ok, %Req.Response{status: status, body: %{"state" => "started"}}}
      when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        wait_for_started_sandbox(sandbox_id, attempts_remaining - 1)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:daytona_get_failed, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_background_job(fun) do
    case Keyword.get(config(), :background_runner) do
      nil -> start_background_task(fun)
      runner when is_function(runner, 1) -> runner.(fun)
    end
  end

  defp start_background_task(fun) do
    task_supervisor = Keyword.get(config(), :task_supervisor, @task_supervisor)

    case Process.whereis(task_supervisor) do
      nil ->
        # Dev code reload does not restart the application supervision tree.
        Task.start(fun)

      _pid ->
        Task.Supervisor.start_child(task_supervisor, fun)
    end
  end

  defp config do
    Application.get_env(:frontman_server, :playgithub, [])
  end

  defp repository_sandbox(
         command,
         repo_url,
         clone_state,
         frontman_install_state,
         sandbox_id,
         sandbox_name,
         sandbox_reused,
         sandbox_state
       ) do
    %{
      command: command,
      repo_url: repo_url,
      clone_state: clone_state,
      frontman_install_state: frontman_install_state,
      frontman_install_error: nil,
      frontman_install_log_path: @frontman_install_log_path,
      dev_server_state: nil,
      dev_server_port: nil,
      dev_server_url: nil,
      dev_server_url_expires_in_seconds: nil,
      dev_server_log_path: nil,
      dev_server_error: nil,
      sandbox_id: sandbox_id,
      sandbox_name: sandbox_name,
      sandbox_reused: sandbox_reused,
      sandbox_state: sandbox_state
    }
  end

  defp failure_reason(%{"result" => result}) when is_binary(result), do: compact_reason(result)
  defp failure_reason(%{"error" => error}) when is_binary(error), do: compact_reason(error)
  defp failure_reason(%{"stderr" => stderr}) when is_binary(stderr), do: compact_reason(stderr)
  defp failure_reason(reason), do: reason |> inspect() |> compact_reason()

  defp compact_reason(reason) do
    compact_reason(reason, @failure_reason_max_length)
  end

  defp compact_reason(reason, max_length) do
    reason =
      reason
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    case String.length(reason) do
      length when length <= max_length ->
        reason

      length ->
        "..." <> String.slice(reason, length - max_length + 3, max_length - 3)
    end
  end

  defp clone_command(%{repo_url: repo_url, github_ref: nil}) do
    "rm -rf workspace && git clone --depth 1 -- #{shell_quote(repo_url)} workspace"
  end

  defp clone_command(%{repo_url: repo_url, github_ref: github_ref}) do
    [
      "rm -rf workspace",
      "git clone --depth 1 -- #{shell_quote(repo_url)} workspace",
      "cd workspace",
      "git fetch --depth 1 origin #{shell_quote(github_ref)}",
      "git checkout --detach FETCH_HEAD"
    ]
    |> Enum.join(" && ")
  end

  defp dev_server_command do
    script =
      [
        "pid=#{shell_quote(@dev_server_pid_path)};",
        "log=#{shell_quote(@dev_server_log_path)};",
        "if [ -f \"$pid\" ] && kill -0 \"$(cat \"$pid\")\" 2>/dev/null; then",
        "printf 'dev server already running pid %s\\n' \"$(cat \"$pid\")\";",
        "else",
        ": > \"$log\";",
        "(npm run dev -- --host 0.0.0.0 --port #{@dev_server_port} >> \"$log\" 2>&1 & echo $! > \"$pid\");",
        "sleep 2;",
        "if kill -0 \"$(cat \"$pid\")\" 2>/dev/null; then",
        "printf 'dev server starting pid %s\\n' \"$(cat \"$pid\")\";",
        "else cat \"$log\"; exit 1; fi; fi"
      ]
      |> Enum.join(" ")

    "sh -lc #{shell_quote(script)}"
  end

  defp dependency_install_command(target) do
    [
      dependency_install_cwd_command(target),
      package_manager_install_command(),
      maybe_build_frontman_astro_command()
    ]
    |> Enum.join(" && ")
  end

  defp dependency_install_cwd_command(%{repo_path: nil}) do
    "cd workspace"
  end

  defp dependency_install_cwd_command(target) do
    package_json_path = "#{target.workspace_path}/package.json"

    [
      "if [ -f #{shell_quote(package_json_path)} ]; then cd #{shell_quote(target.workspace_path)};",
      "else printf '%s\n' #{shell_quote("Path #{package_json_path} does not exist")} >&2; exit 1; fi"
    ]
    |> Enum.join(" ")
  end

  defp package_manager_install_command do
    [
      "if [ -f yarn.lock ]; then YARN_ENABLE_IMMUTABLE_INSTALLS=false corepack yarn install;",
      "elif [ -f pnpm-lock.yaml ]; then corepack pnpm install;",
      "elif [ -f package-lock.json ] || [ -f npm-shrinkwrap.json ]; then npm install;",
      "elif [ -f bun.lock ] || [ -f bun.lockb ]; then bun install;",
      "else npm install; fi"
    ]
    |> Enum.join(" ")
  end

  defp maybe_build_frontman_astro_command do
    [
      "if [ -f node_modules/@frontman-ai/astro/package.json ]",
      "&& [ ! -f node_modules/@frontman-ai/astro/dist/index.js ]; then",
      "package_dir=$(node -e \"process.stdout.write(require('fs').realpathSync('node_modules/@frontman-ai/astro'))\");",
      "printf '\\n[frontman package build]\\n';",
      "(cd \"$package_dir\" && YARN_ENABLE_IMMUTABLE_INSTALLS=false YARN_NETWORK_CONCURRENCY=2 NODE_OPTIONS=--max-old-space-size=512 corepack yarn build);",
      "fi"
    ]
    |> Enum.join(" ")
  end

  defp dependency_install_failure_reason(reason) do
    prefix = "Dependency install failed: "

    prefix <>
      (reason
       |> failure_reason()
       |> compact_reason(@failure_reason_max_length - String.length(prefix)))
  end

  defp logged_install_command(command, stage, reset_log?) do
    reset_command =
      case reset_log? do
        true -> ": > \"$log\""
        false -> "touch \"$log\""
      end

    [
      "log=#{shell_quote(@frontman_install_log_path)}",
      reset_command,
      "printf '\\n[%s] #{stage}\\n' \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" >> \"$log\"",
      "#{command} >> \"$log\" 2>&1",
      "status=$?",
      "printf '\\n[%s] #{stage} exit %s\\n' \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" \"$status\" >> \"$log\"",
      "cat \"$log\"",
      "exit \"$status\""
    ]
    |> Enum.join("; ")
    |> then(fn shell_command -> "sh -lc #{shell_quote(shell_command)}" end)
  end

  defp shell_quote(value) do
    "'" <> String.replace(value, "'", "'\\''") <> "'"
  end

  defp sandbox_name_for_identity(identity) do
    hash =
      :sha256
      |> :crypto.hash(identity)
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
