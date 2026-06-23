# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub do
  @moduledoc """
  Coordinates PlayGithub repository sandboxes.
  """

  alias Daytona.Sandbox, as: DaytonaSandbox
  alias Daytona.Toolbox
  alias Daytona.Toolbox.Git
  alias Daytona.Toolbox.Process, as: ToolboxProcess
  alias FrontmanServer.Accounts
  alias FrontmanServer.PlayGithub.GithubReference
  alias FrontmanServer.PlayGithub.Sandbox
  alias FrontmanServer.Repo

  @frontman_install_command "npx astro add @frontman-ai/astro --yes"
  @frontman_install_log_path "/tmp/frontman-install.log"
  @dev_server_log_path "/tmp/frontman-dev-server.log"
  @dev_server_pid_path "/tmp/frontman-dev-server.pid"
  @dev_server_port 4321
  @dev_server_start_timeout_seconds 10
  @dependency_install_timeout_seconds 600
  @frontman_install_timeout_seconds 300
  @frontman_repository_owner "frontman-ai"
  @frontman_repository_name "frontman"
  @frontman_repository_app_path "apps/marketing"
  @create_stale_after_seconds 600
  @clone_stale_after_seconds 600
  @install_stale_after_seconds 600
  @dev_server_stale_after_seconds 60
  @failure_reason_max_length 1_000
  @repository_clone_timeout_seconds 300
  @sandbox_start_poll_attempts 60
  @sandbox_start_poll_interval_ms 1_000
  @task_supervisor FrontmanServer.PlayGithub.TaskSupervisor

  def get_or_create_repository_sandbox(scope, %GithubReference{} = github_reference) do
    run_repository_command(scope, github_reference, :create)
  end

  def workspace_path(%GithubReference{} = github_reference) do
    launch_workspace_path(github_reference)
  end

  def dev_server_port, do: @dev_server_port

  def get_owned_sandbox_preview_link(scope, sandbox_id, port)
      when is_binary(sandbox_id) and is_integer(port) do
    with {:ok, _sandbox} <- get_owned_sandbox_by_daytona_id(scope, sandbox_id) do
      get_sandbox_preview_link(sandbox_id, port)
    end
  end

  defp get_sandbox_preview_link(sandbox_id, port) do
    daytona = Daytona.new()
    DaytonaSandbox.get_preview_link(daytona, sandbox_id, port)
  end

  def get_owned_sandbox_by_daytona_id(%Accounts.Scope{} = scope, daytona_sandbox_id)
      when is_binary(daytona_sandbox_id) do
    case Repo.one(Sandbox.by_daytona_sandbox_id(scope, daytona_sandbox_id)) do
      nil -> {:error, :playgithub_sandbox_not_found}
      %Sandbox{} = sandbox -> {:ok, sandbox}
    end
  end

  def get_owned_sandbox_by_daytona_id(_scope, daytona_sandbox_id)
      when is_binary(daytona_sandbox_id) do
    {:error, :playgithub_sandbox_not_found}
  end

  def run_repository_command(scope, github_reference, command, opts \\ [])

  def run_repository_command(scope, %GithubReference{} = github_reference, command, opts)
      when command in [:create, :start, :clone, :install, :dev] do
    case GithubReference.repository_backed?(github_reference) do
      true ->
        daytona = Daytona.new()

        with {:ok, sandbox} <- run_command(daytona, scope, github_reference, command, opts) do
          {:ok, %{command: Atom.to_string(command), sandbox: sandbox}}
        end

      false ->
        {:error, :not_repository_path}
    end
  end

  defp run_command(daytona, scope, github_reference, :create, opts) do
    create_repository_sandbox(daytona, scope, github_reference, retry?(opts))
  end

  defp run_command(daytona, scope, github_reference, :start, _opts) do
    start_repository_sandbox(daytona, scope, github_reference)
  end

  defp run_command(daytona, scope, github_reference, :clone, _opts) do
    clone_repository_sandbox(daytona, scope, github_reference)
  end

  defp run_command(daytona, scope, github_reference, :install, opts) do
    install_repository_sandbox(daytona, scope, github_reference, retry?(opts))
  end

  defp run_command(daytona, scope, github_reference, :dev, _opts) do
    start_dev_server_sandbox(daytona, scope, github_reference)
  end

  defp create_repository_sandbox(daytona, scope, github_reference, retry?) do
    with {:ok, sandbox, source} <- get_or_insert_sandbox(scope, github_reference) do
      case create_action(sandbox, source, retry?) do
        :wait -> {:ok, sandbox}
        :start -> create_daytona_sandbox(daytona, sandbox)
      end
    end
  end

  defp start_repository_sandbox(daytona, scope, github_reference) do
    with {:ok, sandbox} <- load_created_sandbox(scope, github_reference),
         :ok <- start_daytona_sandbox(daytona, sandbox) do
      {:ok, sandbox}
    end
  end

  defp clone_repository_sandbox(daytona, scope, github_reference) do
    with {:ok, sandbox} <- load_created_sandbox(scope, github_reference) do
      case clone_action(sandbox) do
        :start -> begin_clone(daytona, sandbox, github_reference)
        :wait -> {:ok, sandbox}
      end
    end
  end

  defp install_repository_sandbox(daytona, scope, github_reference, retry?) do
    with {:ok, sandbox} <- load_created_sandbox(scope, github_reference) do
      case install_action(sandbox, retry?) do
        :start -> begin_install(daytona, sandbox, github_reference)
        :wait -> {:ok, sandbox}
        :not_cloned -> {:error, :repository_not_cloned}
      end
    end
  end

  defp start_dev_server_sandbox(daytona, scope, github_reference) do
    with {:ok, sandbox} <- load_created_sandbox(scope, github_reference) do
      case dev_server_action(sandbox) do
        :start -> begin_dev_server(daytona, sandbox, github_reference)
        :wait -> {:ok, sandbox}
        :not_installed -> {:error, :frontman_not_installed}
      end
    end
  end

  defp get_or_insert_sandbox(scope, github_reference) do
    github_url = GithubReference.github_url(github_reference)
    user_id = Accounts.scope_user_id(scope)

    %Sandbox{user_id: user_id}
    |> Sandbox.create_changeset(%{github_url: github_url})
    |> Repo.insert()
    |> case do
      {:ok, %Sandbox{} = sandbox} ->
        {:ok, sandbox, :inserted}

      {:error, _changeset} ->
        case Repo.one(Sandbox.by_github_url(scope, github_url)) do
          nil ->
            {:error, :playgithub_sandbox_insert_failed}

          %Sandbox{} = sandbox ->
            {:ok, sandbox, :existing}
        end
    end
  end

  defp load_sandbox_record(scope, github_reference) do
    github_url = GithubReference.github_url(github_reference)

    case Repo.one(Sandbox.by_github_url(scope, github_url)) do
      nil -> {:error, :daytona_sandbox_not_found}
      %Sandbox{} = sandbox -> {:ok, sandbox}
    end
  end

  defp load_created_sandbox(scope, github_reference) do
    case load_sandbox_record(scope, github_reference) do
      {:ok, %Sandbox{daytona_sandbox_id: sandbox_id} = sandbox} when is_binary(sandbox_id) ->
        {:ok, sandbox}

      {:ok, %Sandbox{}} ->
        {:error, :daytona_sandbox_not_found}

      error ->
        error
    end
  end

  defp create_action(%Sandbox{daytona_sandbox_id: daytona_sandbox_id}, _source, _retry?)
       when is_binary(daytona_sandbox_id) do
    :wait
  end

  defp create_action(%Sandbox{}, :inserted, _retry?), do: :start

  defp create_action(%Sandbox{status: :sandbox_creating} = sandbox, :existing, _retry?) do
    case stale?(sandbox, @create_stale_after_seconds) do
      true -> :start
      false -> :wait
    end
  end

  defp create_action(%Sandbox{status: :sandbox_create_failed}, :existing, true), do: :start
  defp create_action(%Sandbox{status: :sandbox_create_failed}, :existing, false), do: :wait
  defp create_action(%Sandbox{}, :existing, _retry?), do: :start

  defp create_daytona_sandbox(daytona, sandbox) do
    with {:ok, sandbox} <- persist_status(sandbox, :sandbox_creating) do
      case DaytonaSandbox.create(daytona, %{labels: sandbox_labels(sandbox)}) do
        {:ok, %{id: sandbox_id}} -> attach_daytona_sandbox_id(sandbox, sandbox_id)
        {:error, reason} -> persist_create_failure(sandbox, reason)
      end
    end
  end

  defp sandbox_labels(%Sandbox{} = sandbox) do
    %{
      "frontman.playgithub.sandbox_id" => sandbox.id,
      "frontman.playgithub.github_url" => sandbox.github_url
    }
  end

  defp persist_create_failure(sandbox, reason) do
    persist_status(sandbox, :sandbox_create_failed, failure_reason(reason))
    {:error, reason}
  end

  defp attach_daytona_sandbox_id(sandbox, sandbox_id) do
    sandbox
    |> Sandbox.attach_daytona_sandbox_changeset(sandbox_id)
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp clone_action(%Sandbox{status: :sandbox_created}), do: :start
  defp clone_action(%Sandbox{status: :clone_failed}), do: :start

  defp clone_action(%Sandbox{status: :clone_starting} = sandbox) do
    case stale?(sandbox, @clone_stale_after_seconds) do
      true -> :start
      false -> :wait
    end
  end

  defp clone_action(%Sandbox{} = sandbox) do
    case clone_finished?(sandbox) do
      true -> :wait
      false -> :wait
    end
  end

  defp begin_clone(client, sandbox, github_reference) do
    with {:ok, sandbox} <- persist_status(sandbox, :clone_starting),
         {:ok, _pid} <-
           start_background_job(fn ->
             run_after_sandbox_started(client, sandbox, github_reference, :clone, :clone_failed)
           end) do
      {:ok, sandbox}
    else
      {:error, reason} ->
        persist_status(sandbox, :clone_failed, failure_reason(reason))
        {:error, reason}
    end
  end

  defp clone_repository_in_background(daytona, sandbox, github_reference) do
    case Toolbox.fetch(daytona) do
      {:ok, toolbox} ->
        toolbox
        |> Git.clone(sandbox.daytona_sandbox_id, %{
          request: clone_request(github_reference),
          timeout_seconds: @repository_clone_timeout_seconds
        })
        |> persist_clone_result(sandbox)

      {:error, reason} ->
        persist_status(sandbox, :clone_failed, failure_reason(reason))
    end
  end

  defp persist_clone_result(:ok, sandbox) do
    persist_status(sandbox, :clone_finished)
  end

  defp persist_clone_result({:error, :repository_already_exists}, sandbox) do
    persist_status(sandbox, :clone_finished)
  end

  defp persist_clone_result({:error, reason}, sandbox) do
    persist_status(sandbox, :clone_failed, failure_reason(reason))
  end

  defp clone_request(github_reference) do
    %{url: GithubReference.repository_url(github_reference), path: "workspace"}
    |> maybe_put_branch(GithubReference.branch(github_reference))
  end

  defp maybe_put_branch(request, nil), do: request
  defp maybe_put_branch(request, branch), do: Map.put(request, :branch, branch)

  defp install_action(%Sandbox{status: :clone_finished}, _retry?), do: :start
  defp install_action(%Sandbox{status: :clone_starting}, _retry?), do: :wait
  defp install_action(%Sandbox{status: :clone_failed}, _retry?), do: :not_cloned

  defp install_action(%Sandbox{status: :install_starting} = sandbox, _retry?) do
    case stale?(sandbox, @install_stale_after_seconds) do
      true -> :start
      false -> :wait
    end
  end

  defp install_action(%Sandbox{status: :install_failed}, true), do: :start
  defp install_action(%Sandbox{status: :install_failed}, false), do: :wait

  defp install_action(%Sandbox{} = sandbox, _retry?) do
    case install_finished?(sandbox) do
      true -> :wait
      false -> :not_cloned
    end
  end

  defp begin_install(client, sandbox, github_reference) do
    with {:ok, sandbox} <- persist_status(sandbox, :install_starting),
         {:ok, _pid} <-
           start_background_job(fn ->
             run_after_sandbox_started(
               client,
               sandbox,
               github_reference,
               :install,
               :install_failed
             )
           end) do
      {:ok, sandbox}
    else
      {:error, reason} ->
        persist_status(sandbox, :install_failed, failure_reason(reason))
        {:error, :daytona_frontman_install_failed, reason}
    end
  end

  defp install_frontman_in_background(daytona, sandbox, github_reference) do
    case Toolbox.fetch(daytona) do
      {:ok, toolbox} ->
        case ensure_launch_workspace_path_exists(toolbox, sandbox, github_reference) do
          :ok -> install_dependencies_then_frontman(toolbox, sandbox, github_reference)
          {:error, reason} -> persist_status(sandbox, :install_failed, reason)
        end

      {:error, reason} ->
        persist_status(sandbox, :install_failed, failure_reason(reason))
    end
  end

  defp install_dependencies_then_frontman(toolbox, sandbox, github_reference) do
    case run_dependency_install_command(toolbox, sandbox, github_reference) do
      :ok -> run_frontman_install_command(toolbox, sandbox, github_reference)
      {:error, reason} -> persist_status(sandbox, :install_failed, reason)
    end
  end

  defp ensure_workspace_path_exists(toolbox, sandbox, workspace_path) do
    case toolbox
         |> ToolboxProcess.execute(sandbox.daytona_sandbox_id, %{
           request: %{
             command: "test -d #{shell_quote(workspace_path)}",
             cwd: ".",
             timeout: @frontman_install_timeout_seconds
           }
         }) do
      {:ok, %{exit_code: 0}} ->
        :ok

      {:ok, _result} ->
        {:error, "Path #{workspace_path} does not exist"}

      {:error, _reason} ->
        {:error, "Path #{workspace_path} does not exist"}
    end
  end

  defp run_dependency_install_command(toolbox, sandbox, github_reference) do
    case toolbox
         |> ToolboxProcess.execute(sandbox.daytona_sandbox_id, %{
           request: %{
             command:
               logged_install_command(
                 dependency_install_command(github_reference),
                 "dependency install",
                 true
               ),
             cwd: ".",
             timeout: @dependency_install_timeout_seconds
           }
         }) do
      {:ok, %{exit_code: 0}} ->
        :ok

      {:ok, %{body: body}} ->
        {:error, dependency_install_failure_reason(body)}

      {:error, reason} ->
        {:error, dependency_install_failure_reason(reason)}
    end
  end

  defp run_frontman_install_command(toolbox, sandbox, github_reference) do
    case toolbox
         |> ToolboxProcess.execute(sandbox.daytona_sandbox_id, %{
           request: %{
             command:
               logged_install_command(
                 @frontman_install_command,
                 "frontman install",
                 false
               ),
             cwd: launch_workspace_path(github_reference),
             timeout: @frontman_install_timeout_seconds
           }
         }) do
      {:ok, %{exit_code: 0}} ->
        persist_status(sandbox, :install_finished)

      {:ok, %{body: body}} ->
        persist_status(sandbox, :install_failed, failure_reason(body))

      {:error, reason} ->
        persist_status(sandbox, :install_failed, failure_reason(reason))
    end
  end

  defp dev_server_action(%Sandbox{status: :install_finished}), do: :start
  defp dev_server_action(%Sandbox{status: :dev_server_failed}), do: :start
  defp dev_server_action(%Sandbox{status: :dev_server_started}), do: :wait

  defp dev_server_action(%Sandbox{status: :dev_server_starting} = sandbox) do
    case stale?(sandbox, @dev_server_stale_after_seconds) do
      true -> :start
      false -> :wait
    end
  end

  defp dev_server_action(%Sandbox{}), do: :not_installed

  defp begin_dev_server(client, sandbox, github_reference) do
    with {:ok, sandbox} <- persist_status(sandbox, :dev_server_starting),
         {:ok, _pid} <-
           start_background_job(fn ->
             run_after_sandbox_started(
               client,
               sandbox,
               github_reference,
               :dev,
               :dev_server_failed
             )
           end) do
      {:ok, sandbox}
    else
      {:error, reason} ->
        persist_status(sandbox, :dev_server_failed, failure_reason(reason))
        {:error, reason}
    end
  end

  defp run_dev_server(daytona, sandbox, github_reference) do
    with {:ok, toolbox} <- Toolbox.fetch(daytona),
         :ok <- run_dev_server_command(toolbox, sandbox, github_reference),
         {:ok, _sandbox} <- persist_status(sandbox, :dev_server_started) do
      :ok
    else
      {:error, :daytona_dev_server_failed, body} ->
        persist_status(sandbox, :dev_server_failed, failure_reason(body))

      {:error, reason} ->
        persist_status(sandbox, :dev_server_failed, failure_reason(reason))
    end
  end

  defp run_dev_server_command(toolbox, sandbox, github_reference) do
    case toolbox
         |> ToolboxProcess.execute(sandbox.daytona_sandbox_id, %{
           request: %{
             command: dev_server_command(),
             cwd: launch_workspace_path(github_reference),
             timeout: @dev_server_start_timeout_seconds
           }
         }) do
      {:ok, %{exit_code: 0}} ->
        :ok

      {:ok, %{body: body}} ->
        {:error, :daytona_dev_server_failed, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_after_sandbox_started(client, sandbox, github_reference, work, failed_status) do
    case start_sandbox_until_started(client, sandbox.daytona_sandbox_id) do
      :ok -> run_started_work(client, sandbox, github_reference, work)
      {:error, reason} -> persist_status(sandbox, failed_status, failure_reason(reason))
    end
  end

  defp run_started_work(client, sandbox, github_reference, :clone) do
    clone_repository_in_background(client, sandbox, github_reference)
  end

  defp run_started_work(client, sandbox, github_reference, :install) do
    install_frontman_in_background(client, sandbox, github_reference)
  end

  defp run_started_work(client, sandbox, github_reference, :dev) do
    run_dev_server(client, sandbox, github_reference)
  end

  defp start_daytona_sandbox(client, sandbox) do
    case DaytonaSandbox.start(client, sandbox.daytona_sandbox_id) do
      :started -> :ok
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_sandbox_until_started(client, sandbox_id) do
    case DaytonaSandbox.start(client, sandbox_id) do
      :started ->
        :ok

      :ok ->
        wait_for_started_sandbox(client, sandbox_id, @sandbox_start_poll_attempts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp wait_for_started_sandbox(_client, _sandbox_id, 0), do: {:error, :daytona_start_timeout}

  defp wait_for_started_sandbox(client, sandbox_id, attempts_remaining) do
    Process.sleep(@sandbox_start_poll_interval_ms)

    case DaytonaSandbox.get(client, sandbox_id) do
      {:ok, %{"state" => "started"}} ->
        :ok

      {:ok, _sandbox} ->
        wait_for_started_sandbox(client, sandbox_id, attempts_remaining - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp persist_status(sandbox, status, error \\ nil)

  defp persist_status(%Sandbox{} = sandbox, status, nil) do
    sandbox
    |> Sandbox.status_changeset(status)
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp persist_status(%Sandbox{} = sandbox, status, error) do
    sandbox
    |> Sandbox.failure_status_changeset(status, compact_reason(error))
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp stale?(%Sandbox{status_started_at: nil}, _seconds), do: true

  defp stale?(%Sandbox{status_started_at: started_at}, seconds) do
    DateTime.diff(DateTime.utc_now(:second), started_at, :second) > seconds
  end

  defp clone_finished?(%Sandbox{status: status}) do
    status in [
      :clone_finished,
      :install_starting,
      :install_finished,
      :install_failed,
      :dev_server_starting,
      :dev_server_started,
      :dev_server_failed
    ]
  end

  defp install_finished?(%Sandbox{status: status}) do
    status in [
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

  defp ensure_launch_workspace_path_exists(toolbox, sandbox, github_reference) do
    case launch_workspace_path(github_reference) do
      "workspace" ->
        :ok

      workspace_path ->
        ensure_workspace_path_exists(
          toolbox,
          sandbox,
          workspace_path
        )
    end
  end

  defp launch_workspace_path(github_reference) do
    case frontman_repository_root?(github_reference) do
      true -> "workspace/#{@frontman_repository_app_path}"
      false -> GithubReference.workspace_path(github_reference)
    end
  end

  defp frontman_repository_root?(%GithubReference{} = github_reference) do
    github_reference.owner == @frontman_repository_owner and
      github_reference.repo == @frontman_repository_name and
      GithubReference.repository_path(github_reference) == nil
  end

  defp dependency_install_command(github_reference) do
    case frontman_repository_root?(github_reference) do
      true -> frontman_repository_dependency_install_command()
      false -> default_dependency_install_command(github_reference)
    end
  end

  defp default_dependency_install_command(github_reference) do
    [
      dependency_install_cwd_command(github_reference),
      package_manager_install_command(),
      maybe_build_frontman_astro_command()
    ]
    |> Enum.join(" && ")
  end

  defp frontman_repository_dependency_install_command do
    [
      "cd workspace",
      use_published_frontman_astro_command(),
      "YARN_ENABLE_IMMUTABLE_INSTALLS=false YARN_NETWORK_CONCURRENCY=1 NODE_OPTIONS=--max-old-space-size=512 corepack yarn workspaces focus marketing"
    ]
    |> Enum.join(" && ")
  end

  defp use_published_frontman_astro_command do
    script = """
    const fs = require("fs");
    const path = "#{@frontman_repository_app_path}/package.json";
    const pkg = JSON.parse(fs.readFileSync(path, "utf8"));
    pkg.devDependencies = pkg.devDependencies || {};
    pkg.devDependencies["@frontman-ai/astro"] = "npm:latest";
    fs.writeFileSync(path, JSON.stringify(pkg, null, 2) + "\\n");
    """

    "node -e #{shell_quote(script)}"
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
      "if [ -f yarn.lock ]; then YARN_ENABLE_IMMUTABLE_INSTALLS=false YARN_NETWORK_CONCURRENCY=1 NODE_OPTIONS=--max-old-space-size=512 corepack yarn install;",
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
      "printf '\n[frontman package build]\n';",
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
      "printf '\n[%s] #{stage}\n' \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" >> \"$log\"",
      "#{command} >> \"$log\" 2>&1",
      "status=$?",
      "printf '\n[%s] #{stage} exit %s\n' \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\" \"$status\" >> \"$log\"",
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
