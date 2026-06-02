# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub do
  @moduledoc """
  Coordinates PlayGithub repository sandboxes.
  """

  alias FrontmanServer.PlayGithub.Daytona.Client
  alias FrontmanServer.PlayGithub.Daytona.Sandbox
  alias FrontmanServer.PlayGithub.Daytona.Sandbox.CreateSandbox
  alias FrontmanServer.PlayGithub.Daytona.Toolbox
  alias FrontmanServer.PlayGithub.Daytona.Toolbox.Git
  alias FrontmanServer.PlayGithub.GithubReference
  alias FrontmanServer.PlayGithub.RepositorySandbox

  @frontman_install_command "npx astro add @frontman-ai/astro --yes"
  @frontman_install_log_path "/tmp/frontman-install.log"
  @dev_server_log_path "/tmp/frontman-dev-server.log"
  @dev_server_pid_path "/tmp/frontman-dev-server.pid"
  @dev_server_port 4321
  @dev_server_start_timeout_seconds 10
  @dev_server_preview_expires_seconds 3_600
  @dependency_install_timeout_seconds 600
  @frontman_install_timeout_seconds 300
  @clone_stale_after_seconds 600
  @install_stale_after_seconds 600
  @dev_server_stale_after_seconds 60
  @failure_reason_max_length 1_000
  @repository_clone_timeout_seconds 300
  @sandbox_start_poll_attempts 60
  @sandbox_start_poll_interval_ms 1_000
  @task_supervisor FrontmanServer.PlayGithub.TaskSupervisor

  @type repository_command :: :create | :start | :clone | :install | :dev

  @spec sandbox_name(GithubReference.t()) :: String.t()
  def sandbox_name(%GithubReference{} = github_reference) do
    RepositorySandbox.sandbox_name(github_reference)
  end

  def get_or_create_repository_sandbox(%GithubReference{} = github_reference) do
    run_repository_command(github_reference, :create)
  end

  @spec dev_server_port() :: pos_integer()
  def dev_server_port, do: @dev_server_port

  def get_sandbox_preview_link(sandbox_id, port)
      when is_binary(sandbox_id) and is_integer(port) do
    case Sandbox.get_preview_link(sandbox_id, port) do
      {:ok, %Req.Response{} = response} -> preview_link_from_response(response)
      {:error, reason} -> {:error, reason}
    end
  end

  defp preview_link_from_response(%Req.Response{
         status: status,
         body: %{"url" => url, "token" => token}
       })
       when status in 200..299 and is_binary(url) and is_binary(token) do
    {:ok, %{url: url, preview_token: token}}
  end

  defp preview_link_from_response(%Req.Response{status: status, body: %{"url" => url}})
       when status in 200..299 and is_binary(url) do
    {:ok, %{url: url, preview_token: nil}}
  end

  defp preview_link_from_response(%Req.Response{status: 404}) do
    {:error, :daytona_sandbox_not_found}
  end

  defp preview_link_from_response(%Req.Response{status: status, body: body})
       when status in 200..299 do
    {:error, {:malformed_daytona_preview_response, body}}
  end

  defp preview_link_from_response(%Req.Response{status: status, body: body}) do
    {:error, {:daytona_preview_lookup_failed, status, body}}
  end

  @spec run_repository_command(GithubReference.t(), repository_command(), keyword()) ::
          {:ok, %{command: String.t(), sandbox: RepositorySandbox.t()}}
          | {:error, term()}
          | {:error, term(), term()}
          | {:error, term(), non_neg_integer(), term()}
  def run_repository_command(github_reference, command, opts \\ [])

  def run_repository_command(%GithubReference{} = github_reference, command, opts)
      when command in [:create, :start, :clone, :install, :dev] do
    case GithubReference.repository_backed?(github_reference) do
      true ->
        with {:ok, client} <- Client.new(),
             {:ok, sandbox} <- run_command(client, github_reference, command, opts) do
          {:ok, %{command: Atom.to_string(command), sandbox: sandbox}}
        end

      false ->
        {:error, :not_repository_path}
    end
  end

  defp run_command(_client, github_reference, :create, _opts) do
    create_repository_sandbox(github_reference)
  end

  defp run_command(_client, github_reference, :start, _opts) do
    start_repository_sandbox(github_reference)
  end

  defp run_command(client, github_reference, :clone, _opts) do
    clone_repository_sandbox(client, github_reference)
  end

  defp run_command(client, github_reference, :install, opts) do
    install_repository_sandbox(client, github_reference, retry?(opts))
  end

  defp run_command(client, github_reference, :dev, _opts) do
    start_dev_server_sandbox(client, github_reference)
  end

  defp create_repository_sandbox(github_reference) do
    case load_repository_sandbox(github_reference) do
      {:ok, sandbox} -> {:ok, sandbox}
      {:error, :daytona_sandbox_not_found} -> create_named_repository_sandbox(github_reference)
      error -> error
    end
  end

  defp start_repository_sandbox(github_reference) do
    with {:ok, sandbox} <- load_repository_sandbox(github_reference) do
      start_daytona_sandbox_if_needed(sandbox)
    end
  end

  defp clone_repository_sandbox(client, github_reference) do
    with {:ok, sandbox} <- load_repository_sandbox(github_reference) do
      case clone_action(sandbox) do
        :start -> start_clone(client, sandbox)
        :wait -> {:ok, sandbox}
      end
    end
  end

  defp install_repository_sandbox(client, github_reference, retry?) do
    with {:ok, sandbox} <- load_repository_sandbox(github_reference) do
      case install_action(sandbox, retry?) do
        :start -> start_install(client, sandbox)
        :wait -> {:ok, sandbox}
        :not_cloned -> {:error, :repository_not_cloned}
      end
    end
  end

  defp start_dev_server_sandbox(client, github_reference) do
    with {:ok, sandbox} <- load_repository_sandbox(github_reference) do
      case dev_server_action(sandbox) do
        :start -> start_dev_server(client, sandbox)
        :wait -> {:ok, sandbox}
        :not_installed -> {:error, :frontman_not_installed}
      end
    end
  end

  defp load_repository_sandbox(github_reference) do
    name = RepositorySandbox.sandbox_name(github_reference)

    case Sandbox.get(name) do
      {:ok, %Req.Response{status: status, body: %{"id" => id, "state" => state} = body}}
      when status in 200..299 ->
        labels = Map.get(body, "labels", %{})

        with :ok <- verify_repository_label(github_reference, labels),
             {:ok, provider_state} <- RepositorySandbox.provider_state(state),
             {:ok, lifecycle, started_at, error, dev_server_url} <-
               RepositorySandbox.lifecycle_from_labels(labels) do
          {:ok,
           %RepositorySandbox{
             github_reference: github_reference,
             id: id,
             name: name,
             provider_state: provider_state,
             lifecycle: lifecycle,
             lifecycle_started_at: started_at,
             lifecycle_error: error,
             dev_server_url: dev_server_url
           }}
        end

      {:ok, %Req.Response{status: 404}} ->
        {:error, :daytona_sandbox_not_found}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_get_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp verify_repository_label(github_reference, labels) do
    case Map.fetch(labels, RepositorySandbox.repo_url_label()) do
      {:ok, repo_url} ->
        verify_repository_url(repo_url, GithubReference.repository_url(github_reference), labels)

      _repo_url ->
        {:error, :daytona_repo_label_mismatch, labels}
    end
  end

  defp verify_repository_url(repo_url, repo_url, _labels), do: :ok

  defp verify_repository_url(_repo_url, _expected_repo_url, labels),
    do: {:error, :daytona_repo_label_mismatch, labels}

  defp create_named_repository_sandbox(github_reference) do
    name = RepositorySandbox.sandbox_name(github_reference)

    case Sandbox.create(%CreateSandbox{
           name: name,
           labels: RepositorySandbox.initial_labels(github_reference)
         }) do
      {:ok, %Req.Response{status: status, body: %{"id" => id, "state" => state}}}
      when status in 200..299 ->
        with {:ok, provider_state} <- RepositorySandbox.provider_state(state) do
          {:ok,
           %RepositorySandbox{
             github_reference: github_reference,
             id: id,
             name: name,
             provider_state: provider_state,
             lifecycle: :sandbox_created
           }}
        end

      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:error, :malformed_daytona_response, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_create_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_daytona_sandbox_if_needed(%RepositorySandbox{provider_state: :started} = sandbox) do
    {:ok, sandbox}
  end

  defp start_daytona_sandbox_if_needed(%RepositorySandbox{provider_state: :starting} = sandbox) do
    {:ok, sandbox}
  end

  defp start_daytona_sandbox_if_needed(%RepositorySandbox{} = sandbox) do
    case start_daytona_sandbox(sandbox) do
      {:ok, provider_state} -> {:ok, %{sandbox | provider_state: provider_state}}
      error -> error
    end
  end

  defp clone_action(%RepositorySandbox{lifecycle: :sandbox_created}), do: :start
  defp clone_action(%RepositorySandbox{lifecycle: :clone_failed}), do: :start

  defp clone_action(%RepositorySandbox{lifecycle: :clone_starting} = sandbox) do
    case stale?(sandbox, @clone_stale_after_seconds) do
      true -> :start
      false -> :wait
    end
  end

  defp clone_action(%RepositorySandbox{} = sandbox) do
    case clone_finished?(sandbox) do
      true -> :wait
      false -> :wait
    end
  end

  defp start_clone(client, %RepositorySandbox{provider_state: :started} = sandbox) do
    begin_clone(client, sandbox)
  end

  defp start_clone(_client, %RepositorySandbox{provider_state: :starting} = sandbox) do
    {:ok, sandbox}
  end

  defp start_clone(client, %RepositorySandbox{} = sandbox) do
    start_sandbox_then_work(client, sandbox, :clone)
  end

  defp begin_clone(client, sandbox) do
    with {:ok, sandbox} <- persist_lifecycle(sandbox, :clone_starting),
         {:ok, _pid} <-
           start_background_job(fn -> clone_repository_in_background(client, sandbox) end) do
      {:ok, sandbox}
    else
      {:error, :daytona_label_failed, status, body} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        persist_lifecycle(sandbox, :clone_failed, failure_reason(reason))
        {:error, reason}
    end
  end

  defp clone_repository_in_background(client, sandbox) do
    case Git.clone(client, sandbox.id, clone_request(sandbox.github_reference),
           timeout_seconds: @repository_clone_timeout_seconds
         ) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        persist_lifecycle(sandbox, :clone_finished)

      {:ok, %Req.Response{body: body}} ->
        persist_lifecycle(sandbox, :clone_failed, failure_reason(body))

      {:error, reason} ->
        persist_lifecycle(sandbox, :clone_failed, failure_reason(reason))
    end
  end

  defp clone_request(github_reference) do
    %{url: GithubReference.repository_url(github_reference), path: "workspace"}
    |> maybe_put_branch(GithubReference.branch(github_reference))
  end

  defp maybe_put_branch(request, nil), do: request
  defp maybe_put_branch(request, branch), do: Map.put(request, :branch, branch)

  defp install_action(%RepositorySandbox{lifecycle: :clone_finished}, _retry?), do: :start
  defp install_action(%RepositorySandbox{lifecycle: :clone_starting}, _retry?), do: :wait
  defp install_action(%RepositorySandbox{lifecycle: :sandbox_starting}, _retry?), do: :wait

  defp install_action(%RepositorySandbox{lifecycle: :clone_failed}, _retry?), do: :not_cloned

  defp install_action(%RepositorySandbox{lifecycle: :install_starting} = sandbox, _retry?) do
    case stale?(sandbox, @install_stale_after_seconds) do
      true -> :start
      false -> :wait
    end
  end

  defp install_action(%RepositorySandbox{lifecycle: :install_failed}, true), do: :start
  defp install_action(%RepositorySandbox{lifecycle: :install_failed}, false), do: :wait

  defp install_action(%RepositorySandbox{} = sandbox, _retry?) do
    case install_finished?(sandbox) do
      true -> :wait
      false -> :not_cloned
    end
  end

  defp start_install(client, %RepositorySandbox{provider_state: :started} = sandbox) do
    begin_install(client, sandbox)
  end

  defp start_install(_client, %RepositorySandbox{provider_state: :starting} = sandbox) do
    {:ok, sandbox}
  end

  defp start_install(client, %RepositorySandbox{} = sandbox) do
    start_sandbox_then_work(client, sandbox, :install)
  end

  defp begin_install(client, sandbox) do
    with {:ok, sandbox} <- persist_lifecycle(sandbox, :install_starting),
         {:ok, _pid} <-
           start_background_job(fn -> install_frontman_in_background(client, sandbox) end) do
      {:ok, sandbox}
    else
      {:error, :daytona_label_failed, status, body} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        persist_lifecycle(sandbox, :install_failed, failure_reason(reason))
        {:error, :daytona_frontman_install_failed, reason}
    end
  end

  defp install_frontman_in_background(client, sandbox) do
    case ensure_workspace_path_exists(client, sandbox) do
      :ok -> install_dependencies_then_frontman(client, sandbox)
      {:error, reason} -> persist_lifecycle(sandbox, :install_failed, reason)
    end
  end

  defp install_dependencies_then_frontman(client, sandbox) do
    case run_dependency_install_command(client, sandbox) do
      :ok -> run_frontman_install_command(client, sandbox)
      {:error, reason} -> persist_lifecycle(sandbox, :install_failed, reason)
    end
  end

  defp ensure_workspace_path_exists(client, sandbox, workspace_path) do
    case Toolbox.execute_command(
           client,
           sandbox.id,
           "test -d #{shell_quote(workspace_path)}",
           cwd: ".",
           timeout_seconds: @frontman_install_timeout_seconds
         ) do
      {:ok, %Req.Response{status: status, body: %{"exitCode" => 0}}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{}} ->
        {:error, "Path #{workspace_path} does not exist"}

      {:error, _reason} ->
        {:error, "Path #{workspace_path} does not exist"}
    end
  end

  defp run_dependency_install_command(client, sandbox) do
    case Toolbox.execute_command(
           client,
           sandbox.id,
           logged_install_command(
             dependency_install_command(sandbox.github_reference),
             "dependency install",
             true
           ),
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

  defp run_frontman_install_command(client, sandbox) do
    case Toolbox.execute_command(
           client,
           sandbox.id,
           logged_install_command(@frontman_install_command, "frontman install", false),
           cwd: GithubReference.workspace_path(sandbox.github_reference),
           timeout_seconds: @frontman_install_timeout_seconds
         ) do
      {:ok, %Req.Response{status: status, body: %{"exitCode" => 0}}} when status in 200..299 ->
        persist_lifecycle(sandbox, :install_finished)

      {:ok, %Req.Response{body: body}} ->
        persist_lifecycle(sandbox, :install_failed, failure_reason(body))

      {:error, reason} ->
        persist_lifecycle(sandbox, :install_failed, failure_reason(reason))
    end
  end

  defp dev_server_action(%RepositorySandbox{lifecycle: :install_finished}), do: :start
  defp dev_server_action(%RepositorySandbox{lifecycle: :dev_server_failed}), do: :start
  defp dev_server_action(%RepositorySandbox{lifecycle: :dev_server_started}), do: :wait

  defp dev_server_action(%RepositorySandbox{lifecycle: :dev_server_starting} = sandbox) do
    case stale?(sandbox, @dev_server_stale_after_seconds) do
      true -> :start
      false -> :wait
    end
  end

  defp dev_server_action(%RepositorySandbox{}), do: :not_installed

  defp start_dev_server(client, %RepositorySandbox{provider_state: :started} = sandbox) do
    run_dev_server(client, sandbox)
  end

  defp start_dev_server(_client, %RepositorySandbox{provider_state: :starting} = sandbox) do
    {:ok, sandbox}
  end

  defp start_dev_server(client, %RepositorySandbox{} = sandbox) do
    start_sandbox_then_work(client, sandbox, :dev)
  end

  defp run_dev_server(client, sandbox) do
    with {:ok, sandbox} <- persist_lifecycle(sandbox, :dev_server_starting),
         :ok <- run_dev_server_command(client, sandbox),
         {:ok, dev_server_url} <- create_dev_server_preview_url(sandbox.id),
         {:ok, sandbox} <- persist_lifecycle(sandbox, :dev_server_started, nil, dev_server_url) do
      {:ok, sandbox}
    else
      {:error, :daytona_label_failed, status, body} ->
        {:error, :daytona_label_failed, status, body}

      {:error, :daytona_dev_server_failed, status, body} ->
        persist_lifecycle(sandbox, :dev_server_failed, failure_reason(body))
        {:error, :daytona_dev_server_failed, status, body}

      {:error, :daytona_preview_url_failed, status, body} ->
        persist_lifecycle(sandbox, :dev_server_failed, failure_reason(body))
        {:error, :daytona_preview_url_failed, status, body}

      {:error, reason, body} ->
        persist_lifecycle(sandbox, :dev_server_failed, failure_reason(body))
        {:error, reason, body}

      {:error, reason} ->
        persist_lifecycle(sandbox, :dev_server_failed, failure_reason(reason))
        {:error, reason}
    end
  end

  defp run_dev_server_command(client, sandbox) do
    case Toolbox.execute_command(
           client,
           sandbox.id,
           dev_server_command(),
           cwd: GithubReference.workspace_path(sandbox.github_reference),
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
    case Sandbox.get_signed_preview_url(
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

  defp start_sandbox_then_work(client, sandbox, work) do
    with {:ok, sandbox} <- persist_lifecycle(sandbox, :sandbox_starting),
         {:ok, _pid} <-
           start_background_job(fn ->
             start_sandbox_then_work_in_background(client, sandbox, work)
           end) do
      {:ok, %{sandbox | provider_state: :starting}}
    else
      {:error, :daytona_label_failed, status, body} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        persist_failed_lifecycle(sandbox, work, reason)
        {:error, reason}
    end
  end

  defp start_sandbox_then_work_in_background(client, sandbox, work) do
    case start_sandbox_until_started(sandbox.id) do
      :ok -> run_work_in_background(client, %{sandbox | provider_state: :started}, work)
      {:error, reason} -> persist_failed_lifecycle(sandbox, work, reason)
    end
  end

  defp run_work_in_background(client, sandbox, :clone) do
    with {:ok, sandbox} <- persist_lifecycle(sandbox, :clone_starting) do
      clone_repository_in_background(client, sandbox)
    end
  end

  defp run_work_in_background(client, sandbox, :install) do
    with {:ok, sandbox} <- persist_lifecycle(sandbox, :install_starting) do
      install_frontman_in_background(client, sandbox)
    end
  end

  defp run_work_in_background(client, sandbox, :dev) do
    run_dev_server(client, sandbox)
  end

  defp persist_failed_lifecycle(sandbox, :clone, reason) do
    persist_lifecycle(sandbox, :clone_failed, failure_reason(reason))
  end

  defp persist_failed_lifecycle(sandbox, :install, reason) do
    persist_lifecycle(sandbox, :install_failed, failure_reason(reason))
  end

  defp persist_failed_lifecycle(sandbox, :dev, reason) do
    persist_lifecycle(sandbox, :dev_server_failed, failure_reason(reason))
  end

  defp start_daytona_sandbox(sandbox) do
    case Sandbox.start(sandbox.id) do
      {:ok, %Req.Response{status: status, body: %{"state" => "started"}}}
      when status in 200..299 ->
        {:ok, :started}

      {:ok, %Req.Response{status: status, body: %{"state" => state}}} when status in 200..299 ->
        RepositorySandbox.provider_state(state)

      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok, :starting}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_start_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_sandbox_until_started(sandbox_id) do
    case Sandbox.start(sandbox_id) do
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

    case Sandbox.get(sandbox_id) do
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

  defp persist_lifecycle(sandbox, lifecycle, error \\ nil, dev_server_url \\ nil) do
    started_at = lifecycle_started_at(lifecycle)

    labels =
      RepositorySandbox.labels(sandbox.github_reference, lifecycle,
        started_at: started_at,
        error: error,
        dev_server_url: dev_server_url
      )

    case Sandbox.replace_labels(sandbox.id, labels) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        {:ok,
         %{
           sandbox
           | lifecycle: lifecycle,
             lifecycle_started_at: started_at,
             lifecycle_error: error,
             dev_server_url: dev_server_url
         }}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, :daytona_label_failed, status, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp lifecycle_started_at(:sandbox_starting), do: System.system_time(:second)
  defp lifecycle_started_at(:clone_starting), do: System.system_time(:second)
  defp lifecycle_started_at(:install_starting), do: System.system_time(:second)
  defp lifecycle_started_at(:dev_server_starting), do: System.system_time(:second)
  defp lifecycle_started_at(:dev_server_started), do: System.system_time(:second)
  defp lifecycle_started_at(_lifecycle), do: nil

  defp stale?(%RepositorySandbox{lifecycle_started_at: nil}, _seconds), do: true

  defp stale?(%RepositorySandbox{lifecycle_started_at: started_at}, seconds) do
    System.system_time(:second) - started_at > seconds
  end

  defp clone_finished?(%RepositorySandbox{lifecycle: lifecycle}) do
    lifecycle in [
      :clone_finished,
      :install_starting,
      :install_finished,
      :install_failed,
      :dev_server_starting,
      :dev_server_started,
      :dev_server_failed
    ]
  end

  defp install_finished?(%RepositorySandbox{lifecycle: lifecycle}) do
    lifecycle in [
      :install_finished,
      :dev_server_starting,
      :dev_server_started,
      :dev_server_failed
    ]
  end

  defp retry?(opts), do: Keyword.get(opts, :retry, false)

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

  defp ensure_workspace_path_exists(client, sandbox) do
    case GithubReference.repository_path(sandbox.github_reference) do
      nil ->
        :ok

      _path ->
        ensure_workspace_path_exists(
          client,
          sandbox,
          GithubReference.workspace_path(sandbox.github_reference)
        )
    end
  end

  defp dependency_install_command(github_reference) do
    [
      dependency_install_cwd_command(github_reference),
      package_manager_install_command(),
      maybe_build_frontman_astro_command()
    ]
    |> Enum.join(" && ")
  end

  defp dependency_install_cwd_command(github_reference) do
    case GithubReference.repository_path(github_reference) do
      nil ->
        "cd workspace"

      _path ->
        workspace_path = GithubReference.workspace_path(github_reference)
        package_json_path = "#{workspace_path}/package.json"

        [
          "if [ -f #{shell_quote(package_json_path)} ]; then cd #{shell_quote(workspace_path)};",
          "else printf '%s\n' #{shell_quote("Path #{package_json_path} does not exist")} >&2; exit 1; fi"
        ]
        |> Enum.join(" ")
    end
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

  defp dependency_install_failure_reason(reason) do
    prefix = "Dependency install failed: "

    prefix <>
      (reason
       |> failure_reason()
       |> compact_reason(@failure_reason_max_length - String.length(prefix)))
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
      length when length <= max_length -> reason
      length -> "..." <> String.slice(reason, length - max_length + 3, max_length - 3)
    end
  end

  defp shell_quote(value) do
    "'" <> String.replace(value, "'", "'\\''") <> "'"
  end
end
