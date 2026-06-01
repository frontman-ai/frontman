defmodule FrontmanServerWeb.PlayGithub.ControllerTest do
  use FrontmanServerWeb.ConnCase, async: false

  alias FrontmanServer.PlayGithub
  alias FrontmanServer.PlayGithub.GithubReference

  setup do
    previous_playgithub = Application.get_env(:frontman_server, :playgithub)
    test_pid = self()

    playgithub_config = previous_playgithub || []

    Application.put_env(
      :frontman_server,
      :playgithub,
      Keyword.put(playgithub_config, :background_runner, fn fun ->
        send(test_pid, {:playgithub_background_job, fun})
        {:ok, test_pid}
      end)
    )

    on_exit(fn -> restore_env(:playgithub, previous_playgithub) end)

    :ok
  end

  describe "GET / on playgithub.frontman.local" do
    test "redirects unauthenticated users to log in", %{conn: conn} do
      conn = get_playgithub(conn, ~p"/")

      assert redirected_to(conn) =~ "https://frontman.local:4002/users/log-in"
      assert redirected_to(conn) =~ "return_to="
    end

    test "redirects unauthenticated nested paths to log in", %{conn: conn} do
      conn = get_playgithub(conn, "/octocat/Hello-World")

      assert redirected_to(conn) =~ "https://frontman.local:4002/users/log-in"
      assert redirected_to(conn) =~ "return_to="
    end
  end

  describe "GET / on playgithub.frontman.local for authenticated users" do
    setup :register_and_log_in_user

    test "uses the PlayGithub route for authenticated users", %{conn: conn} do
      conn = get_playgithub(conn, ~p"/")

      assert html_response(conn, 200) =~ "PlayGithub local subdomain is routed"
    end

    test "requires explicit repository command", %{conn: conn} do
      conn = get_playgithub(conn, "/octocat/Hello-World")

      assert text_response(conn, 400) =~ "error: missing_command"
    end

    test "rejects unsupported repository commands", %{conn: conn} do
      conn = get_playgithub(conn, "/octocat/Hello-World?command=build")

      assert text_response(conn, 400) =~ "error: unsupported_command"
      assert text_response(conn, 400) =~ "usage: ?command=create|start|clone|install|dev"
    end

    test "creates Daytona sandbox for new repository path", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_missing_sandbox(sandbox_name)
      expect_daytona_create_sandbox(sandbox_name)

      conn = get_playgithub(conn, "/octocat/Hello-World?command=create")

      assert_response_lines(text_response(conn, 200), [
        "command: create",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: false",
        "clone_state: not_started",
        "frontman_install_state: not_started",
        "next: open_frontman_editor"
      ])
    end

    test "creates Daytona sandbox for tree path independently from repository sandbox", %{
      conn: conn
    } do
      sandbox_name = tree_sandbox_name()

      expect_daytona_get_missing_sandbox(sandbox_name)
      expect_daytona_create_sandbox(sandbox_name)

      conn = get_playgithub(conn, "/octocat/Hello-World/tree/main/apps/marketing?command=create")

      assert_response_lines(text_response(conn, 200), [
        "command: create",
        "repo_url: https://github.com/octocat/Hello-World",
        "github_ref: main",
        "repo_path: apps/marketing",
        "workspace_path: workspace/apps/marketing",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: false",
        "clone_state: not_started",
        "frontman_install_state: not_started",
        "next: open_frontman_editor"
      ])
    end

    test "reuses Daytona sandbox for existing repository path", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(sandbox_name)

      conn = get_playgithub(conn, "/octocat/Hello-World?command=create")

      assert_response_lines(text_response(conn, 200), [
        "command: create",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installed",
        "next: open_frontman_editor"
      ])
    end

    test "starts stopped Daytona sandbox explicitly", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        "installed",
        "stopped"
      )

      expect_daytona_start_sandbox("starting")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=start")

      assert_response_lines(text_response(conn, 200), [
        "command: start",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: starting",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installed",
        "next: wait_for_daytona_start"
      ])
    end

    test "start command reuses already started sandbox", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(sandbox_name)

      conn = get_playgithub(conn, "/octocat/Hello-World?command=start")

      assert_response_lines(text_response(conn, 200), [
        "command: start",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installed",
        "next: open_frontman_editor"
      ])
    end

    test "start command requires existing sandbox", %{conn: conn} do
      expect_daytona_get_missing_sandbox(sandbox_name())

      conn = get_playgithub(conn, "/octocat/Hello-World?command=start")

      assert text_response(conn, 404) =~ "error: daytona_sandbox_not_found"
    end

    test "clones existing repository sandbox", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        nil
      )

      expect_daytona_replace_labels("cloning")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=clone")

      assert_response_lines(text_response(conn, 200), [
        "command: clone",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloning",
        "frontman_install_state: waiting_for_clone",
        "next: open_frontman_editor"
      ])

      expect_daytona_clone_repository()
      expect_daytona_replace_labels("cloned")
      run_background_job()
    end

    test "clones tree path by checking out requested ref", %{conn: conn} do
      sandbox_name = tree_sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        nil
      )

      expect_daytona_replace_labels("cloning")

      conn = get_playgithub(conn, "/octocat/Hello-World/tree/main/apps/marketing?command=clone")

      assert_response_lines(text_response(conn, 200), [
        "command: clone",
        "repo_url: https://github.com/octocat/Hello-World",
        "github_ref: main",
        "repo_path: apps/marketing",
        "workspace_path: workspace/apps/marketing",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloning",
        "frontman_install_state: waiting_for_clone",
        "next: open_frontman_editor"
      ])

      expect_daytona_clone_repository_with_command(tree_clone_command())
      expect_daytona_replace_labels("cloned")
      run_background_job()
    end

    test "falls back when dev code reload has not started the task supervisor", %{conn: conn} do
      sandbox_name = sandbox_name()
      use_missing_task_supervisor()
      stub_daytona_clone_flow(sandbox_name, self())
      sandbox_path = "/api/sandbox/#{sandbox_name}"
      clone_command = clone_command()

      conn = get_playgithub(conn, "/octocat/Hello-World?command=clone")

      assert_response_lines(text_response(conn, 200), [
        "command: clone",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloning",
        "frontman_install_state: waiting_for_clone",
        "next: open_frontman_editor"
      ])

      assert_receive {:daytona_request, "GET", ^sandbox_path, nil}

      assert_receive {:daytona_request, "PUT", "/api/sandbox/sandbox_123/labels", body}

      assert %{
               "labels" => %{
                 "frontman.playgithub.clone_state" => "cloning",
                 "frontman.playgithub.clone_started_at" => clone_started_at,
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             } = body

      assert {_, ""} = Integer.parse(clone_started_at)

      assert_receive {:daytona_request, "POST",
                      "/api/toolbox/sandbox_123/toolbox/process/execute",
                      %{
                        "command" => ^clone_command,
                        "cwd" => ".",
                        "timeout" => 300
                      }}

      assert_receive {:daytona_request, "PUT", "/api/sandbox/sandbox_123/labels",
                      %{
                        "labels" => %{
                          "frontman.playgithub.cloned" => "true",
                          "frontman.playgithub.clone_state" => "cloned",
                          "frontman.playgithub.repo_url" =>
                            "https://github.com/octocat/Hello-World"
                        }
                      }}
    end

    test "installs Frontman when existing sandbox is cloned without install state", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        nil
      )

      expect_daytona_replace_labels("installing")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=install")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installing",
        "next: open_frontman_editor"
      ])

      expect_daytona_install_dependencies()
      expect_daytona_install_frontman()
      expect_daytona_replace_labels("installed")
      run_background_job()
    end

    test "installs Frontman from tree workspace path", %{conn: conn} do
      sandbox_name = tree_sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        nil
      )

      expect_daytona_replace_labels("installing")

      conn = get_playgithub(conn, "/octocat/Hello-World/tree/main/apps/marketing?command=install")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "github_ref: main",
        "repo_path: apps/marketing",
        "workspace_path: workspace/apps/marketing",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installing",
        "next: open_frontman_editor"
      ])

      expect_daytona_check_workspace_path("workspace/apps/marketing")
      expect_daytona_install_dependencies(0, "workspace/apps/marketing")
      expect_daytona_install_frontman(0, "workspace/apps/marketing")
      expect_daytona_replace_labels("installed")
      run_background_job()
    end

    test "marks tree install failed when workspace path is missing", %{conn: conn} do
      sandbox_name = tree_sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        nil
      )

      expect_daytona_replace_labels("installing")

      conn = get_playgithub(conn, "/octocat/Hello-World/tree/main/apps/marketing?command=install")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "github_ref: main",
        "repo_path: apps/marketing",
        "workspace_path: workspace/apps/marketing",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installing",
        "next: open_frontman_editor"
      ])

      expect_daytona_check_workspace_path("workspace/apps/marketing", 1)
      expect_daytona_replace_install_failed_labels("Path workspace/apps/marketing does not exist")
      run_background_job()
    end

    test "marks tree install failed when package json is missing", %{conn: conn} do
      sandbox_name = tree_sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        nil
      )

      expect_daytona_replace_labels("installing")

      conn = get_playgithub(conn, "/octocat/Hello-World/tree/main/apps/marketing?command=install")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "github_ref: main",
        "repo_path: apps/marketing",
        "workspace_path: workspace/apps/marketing",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installing",
        "next: open_frontman_editor"
      ])

      expect_daytona_check_workspace_path("workspace/apps/marketing")

      expect_daytona_install_dependencies(
        1,
        "workspace/apps/marketing",
        "Path workspace/apps/marketing/package.json does not exist"
      )

      expect_daytona_replace_install_failed_labels(
        "Dependency install failed: Path workspace/apps/marketing/package.json does not exist"
      )

      run_background_job()
    end

    test "starts dev server from tree workspace path", %{conn: conn} do
      sandbox_name = tree_sandbox_name()

      expect_daytona_get_existing_sandbox_with_labels(
        sandbox_name,
        %{
          "frontman.playgithub.cloned" => "true",
          "frontman.playgithub.clone_state" => "cloned",
          "frontman.playgithub.dev_server_error" => "sh: 1: Syntax error",
          "frontman.playgithub.dev_server_state" => "failed",
          "frontman.playgithub.frontman_install_state" => "installed",
          "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
        },
        "started"
      )

      expect_daytona_start_dev_server("workspace/apps/marketing")
      expect_daytona_create_signed_preview_url()
      expect_daytona_replace_dev_server_labels("https://4321-preview.proxy.daytona.work")

      conn = get_playgithub(conn, "/octocat/Hello-World/tree/main/apps/marketing?command=dev")

      response = text_response(conn, 200)

      assert_response_lines(response, [
        "command: dev",
        "repo_url: https://github.com/octocat/Hello-World",
        "github_ref: main",
        "repo_path: apps/marketing",
        "workspace_path: workspace/apps/marketing",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installed",
        "dev_server_state: starting",
        "dev_server_port: 4321",
        "dev_server_log: /tmp/frontman-dev-server.log",
        "dev_server_url: https://4321-preview.proxy.daytona.work",
        "dev_server_url_expires_in_seconds: 3600",
        "frontman_preview_url:",
        "url=https%3A%2F%2F4321-preview.proxy.daytona.work",
        "next: open_frontman_preview"
      ])

      refute response =~ "dev_server_error:"
    end

    test "dev command requires installed Frontman", %{conn: conn} do
      sandbox_name = tree_sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        "install_failed"
      )

      conn = get_playgithub(conn, "/octocat/Hello-World/tree/main/apps/marketing?command=dev")

      assert text_response(conn, 409) =~ "error: frontman_not_installed"
    end

    test "skips install while existing sandbox is installing Frontman", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        "installing"
      )

      conn = get_playgithub(conn, "/octocat/Hello-World?command=install")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installing",
        "next: open_frontman_editor"
      ])
    end

    test "retries legacy installing label without timestamp", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox_with_labels(
        sandbox_name,
        %{
          "frontman.playgithub.cloned" => "true",
          "frontman.playgithub.clone_state" => "cloned",
          "frontman.playgithub.frontman_install_state" => "installing",
          "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
        },
        "started"
      )

      expect_daytona_replace_labels("installing")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=install")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installing",
        "next: open_frontman_editor"
      ])

      expect_daytona_install_dependencies()
      expect_daytona_install_frontman()
      expect_daytona_replace_labels("installed")
      run_background_job()
    end

    test "reports existing Frontman install failure without retrying", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox_with_labels(
        sandbox_name,
        %{
          "frontman.playgithub.cloned" => "true",
          "frontman.playgithub.clone_state" => "cloned",
          "frontman.playgithub.frontman_install_error" => "Astro could not detect a project",
          "frontman.playgithub.frontman_install_state" => "install_failed",
          "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
        },
        "started"
      )

      conn = get_playgithub(conn, "/octocat/Hello-World?command=install")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: install_failed",
        "frontman_install_error: Astro could not detect a project",
        "next: open_frontman_editor"
      ])
    end

    test "retries existing Frontman install failure when requested", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        "install_failed"
      )

      expect_daytona_replace_labels("installing")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=install&retry=true")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installing",
        "next: open_frontman_editor"
      ])

      expect_daytona_install_dependencies()
      expect_daytona_install_frontman(1)
      expect_daytona_replace_labels("install_failed")
      run_background_job()
    end

    test "skips clone while existing sandbox is cloning", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloning"
      )

      conn = get_playgithub(conn, "/octocat/Hello-World?command=clone")

      assert_response_lines(text_response(conn, 200), [
        "command: clone",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloning",
        "frontman_install_state: waiting_for_clone",
        "next: open_frontman_editor"
      ])
    end

    test "retries legacy cloning label without timestamp", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox_with_labels(
        sandbox_name,
        %{
          "frontman.playgithub.clone_state" => "cloning",
          "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
        },
        "started"
      )

      expect_daytona_replace_labels("cloning")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=clone")

      assert_response_lines(text_response(conn, 200), [
        "command: clone",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloning",
        "frontman_install_state: waiting_for_clone",
        "next: open_frontman_editor"
      ])

      expect_daytona_clone_repository()
      expect_daytona_replace_labels("cloned")
      run_background_job()
    end

    test "marks failed clone command explicitly", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        nil
      )

      expect_daytona_replace_labels("cloning")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=clone")

      assert_response_lines(text_response(conn, 200), [
        "command: clone",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloning",
        "frontman_install_state: waiting_for_clone",
        "next: open_frontman_editor"
      ])

      expect_daytona_clone_repository(1)
      expect_daytona_replace_labels("failed")
      run_background_job()
    end

    test "starts stopped sandbox before cloning stale cloning label", %{
      conn: conn
    } do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloning",
        nil,
        "stopped"
      )

      expect_daytona_replace_labels("clone_waiting_for_started")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=clone")

      assert_response_lines(text_response(conn, 200), [
        "command: clone",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: starting",
        "sandbox_reused: true",
        "clone_state: waiting_for_started",
        "frontman_install_state: waiting_for_clone",
        "next: wait_for_daytona_start"
      ])

      expect_daytona_start_sandbox()
      expect_daytona_replace_labels("cloning")
      expect_daytona_clone_repository()
      expect_daytona_replace_labels("cloned")
      run_background_job()
    end

    test "starts stopped sandbox before installing Frontman", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        nil,
        "stopped"
      )

      expect_daytona_replace_labels("install_waiting_for_started")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=install")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: starting",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: waiting_for_started",
        "next: wait_for_daytona_start"
      ])

      expect_daytona_start_sandbox()
      expect_daytona_replace_labels("installing")
      expect_daytona_install_dependencies()
      expect_daytona_install_frontman()
      expect_daytona_replace_labels("installed")
      run_background_job()
    end

    test "marks failed Frontman install explicitly", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        nil
      )

      expect_daytona_replace_labels("installing")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=install")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installing",
        "next: open_frontman_editor"
      ])

      expect_daytona_install_dependencies()
      expect_daytona_install_frontman(1)
      expect_daytona_replace_labels("install_failed")
      run_background_job()
    end

    test "marks failed dependency install explicitly", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        nil
      )

      expect_daytona_replace_labels("installing")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=install")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installing",
        "next: open_frontman_editor"
      ])

      expect_daytona_install_dependencies(1)

      expect_daytona_replace_install_failed_labels(
        "Dependency install failed: dependency install output"
      )

      run_background_job()
    end

    test "keeps dependency install failure tail", %{conn: conn} do
      sandbox_name = sandbox_name()
      dependency_output = String.duplicate("yarn warning ", 120) <> "real yarn failure at end"

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        "cloned",
        nil
      )

      expect_daytona_replace_labels("installing")

      conn = get_playgithub(conn, "/octocat/Hello-World?command=install")

      assert_response_lines(text_response(conn, 200), [
        "command: install",
        "repo_url: https://github.com/octocat/Hello-World",
        "sandbox_name: #{sandbox_name}",
        "sandbox_id: sandbox_123",
        "sandbox_state: started",
        "sandbox_reused: true",
        "clone_state: cloned",
        "frontman_install_state: installing",
        "next: open_frontman_editor"
      ])

      expect_daytona_install_dependencies(1, "workspace", dependency_output)

      expected_error =
        "Dependency install failed: #{compact_failure_tail(dependency_output, 973)}"

      expect_daytona_replace_install_failed_labels(expected_error)
      run_background_job()
    end

    test "clone command requires existing sandbox", %{conn: conn} do
      expect_daytona_get_missing_sandbox(sandbox_name())

      conn = get_playgithub(conn, "/octocat/Hello-World?command=clone")

      assert text_response(conn, 404) =~ "error: daytona_sandbox_not_found"
    end

    test "install command requires cloned repository", %{conn: conn} do
      sandbox_name = sandbox_name()

      expect_daytona_get_existing_sandbox(
        sandbox_name,
        "https://github.com/octocat/Hello-World",
        nil,
        nil
      )

      conn = get_playgithub(conn, "/octocat/Hello-World?command=install")

      assert text_response(conn, 409) =~ "error: repository_not_cloned"
    end

    test "rejects existing sandbox with mismatched repo label", %{conn: conn} do
      expect_daytona_get_existing_sandbox(
        sandbox_name(),
        "https://github.com/octocat/Spoon-Knife"
      )

      conn = get_playgithub(conn, "/octocat/Hello-World?command=create")

      assert text_response(conn, 409) =~ "error: daytona_repo_label_mismatch"
    end
  end

  test "does not replace the default root route", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == "https://frontman.sh"
  end

  defp restore_env(key, nil), do: Application.delete_env(:frontman_server, key)
  defp restore_env(key, value), do: Application.put_env(:frontman_server, key, value)

  defp run_background_job do
    assert_receive {:playgithub_background_job, job}
    job.()
  end

  defp use_missing_task_supervisor do
    playgithub_config =
      :frontman_server
      |> Application.fetch_env!(:playgithub)
      |> Keyword.delete(:background_runner)
      |> Keyword.put(:task_supervisor, FrontmanServer.PlayGithub.MissingTaskSupervisor)

    Application.put_env(:frontman_server, :playgithub, playgithub_config)
  end

  defp get_playgithub(conn, path) do
    conn
    |> Map.put(:host, "playgithub.frontman.local")
    |> get(path)
  end

  defp sandbox_name do
    {:ok, github_path} = GithubReference.parse_path(["octocat", "Hello-World"])

    PlayGithub.sandbox_name(github_path)
  end

  defp tree_sandbox_name do
    {:ok, github_path} =
      GithubReference.parse_path(["octocat", "Hello-World", "tree", "main", "apps", "marketing"])

    PlayGithub.sandbox_name(github_path)
  end

  defp expect_daytona_get_missing_sandbox(sandbox_name) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/sandbox/#{sandbox_name}"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      conn
      |> Plug.Conn.put_status(404)
      |> Req.Test.json(%{})
    end)
  end

  defp expect_daytona_get_existing_sandbox(sandbox_name) do
    expect_daytona_get_existing_sandbox(
      sandbox_name,
      "https://github.com/octocat/Hello-World",
      "cloned",
      "installed"
    )
  end

  defp expect_daytona_get_existing_sandbox(sandbox_name, repo_url) do
    expect_daytona_get_existing_sandbox(sandbox_name, repo_url, "cloned", "installed")
  end

  defp expect_daytona_get_existing_sandbox(sandbox_name, repo_url, clone_state) do
    expect_daytona_get_existing_sandbox(
      sandbox_name,
      repo_url,
      clone_state,
      default_frontman_install_state(clone_state)
    )
  end

  defp expect_daytona_get_existing_sandbox(
         sandbox_name,
         repo_url,
         clone_state,
         frontman_install_state
       ) do
    expect_daytona_get_existing_sandbox(
      sandbox_name,
      repo_url,
      clone_state,
      frontman_install_state,
      "started"
    )
  end

  defp expect_daytona_get_existing_sandbox(
         sandbox_name,
         repo_url,
         clone_state,
         frontman_install_state,
         sandbox_state
       ) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/sandbox/#{sandbox_name}"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      Req.Test.json(conn, %{
        "id" => "sandbox_123",
        "labels" => repository_labels(repo_url, clone_state, frontman_install_state),
        "state" => sandbox_state
      })
    end)
  end

  defp expect_daytona_get_existing_sandbox_with_labels(sandbox_name, labels, sandbox_state) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/sandbox/#{sandbox_name}"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      Req.Test.json(conn, %{
        "id" => "sandbox_123",
        "labels" => labels,
        "state" => sandbox_state
      })
    end)
  end

  defp default_frontman_install_state("cloned"), do: "installed"
  defp default_frontman_install_state(_clone_state), do: nil

  defp repository_labels(repo_url, clone_state, frontman_install_state) do
    %{
      "frontman.playgithub.repo_url" => repo_url
    }
    |> maybe_put_clone_state(clone_state)
    |> maybe_put_clone_started_at(clone_state)
    |> maybe_put_cloned(clone_state)
    |> maybe_put_frontman_install_state(frontman_install_state)
    |> maybe_put_frontman_install_started_at(frontman_install_state)
  end

  defp maybe_put_clone_state(labels, nil), do: labels

  defp maybe_put_clone_state(labels, clone_state) do
    Map.put(labels, "frontman.playgithub.clone_state", clone_state)
  end

  defp maybe_put_clone_started_at(labels, "cloning") do
    Map.put(labels, "frontman.playgithub.clone_started_at", "9999999999")
  end

  defp maybe_put_clone_started_at(labels, _clone_state), do: labels

  defp maybe_put_cloned(labels, "cloned") do
    Map.put(labels, "frontman.playgithub.cloned", "true")
  end

  defp maybe_put_cloned(labels, _clone_state), do: labels

  defp maybe_put_frontman_install_state(labels, nil), do: labels

  defp maybe_put_frontman_install_state(labels, frontman_install_state) do
    Map.put(labels, "frontman.playgithub.frontman_install_state", frontman_install_state)
  end

  defp maybe_put_frontman_install_started_at(labels, "installing") do
    Map.put(labels, "frontman.playgithub.frontman_install_started_at", "9999999999")
  end

  defp maybe_put_frontman_install_started_at(labels, _frontman_install_state), do: labels

  defp expect_daytona_create_sandbox(sandbox_name) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/sandbox"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "name" => sandbox_name,
               "labels" => %{
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             }

      Req.Test.json(conn, %{
        "id" => "sandbox_123",
        "state" => "started"
      })
    end)
  end

  defp stub_daytona_clone_flow(sandbox_name, test_pid) do
    Req.Test.stub(:playgithub_daytona, fn conn ->
      {body, conn} = read_json_body(conn)
      send(test_pid, {:daytona_request, conn.method, conn.request_path, body})

      case {conn.method, conn.request_path} do
        {"GET", "/api/sandbox/" <> ^sandbox_name} ->
          Req.Test.json(conn, %{
            "id" => "sandbox_123",
            "labels" => repository_labels("https://github.com/octocat/Hello-World", nil, nil),
            "state" => "started"
          })

        {"PUT", "/api/sandbox/sandbox_123/labels"} ->
          Req.Test.json(conn, %{})

        {"POST", "/api/toolbox/sandbox_123/toolbox/process/execute"} ->
          Req.Test.json(conn, %{"exitCode" => 0, "result" => "cloned"})
      end
    end)
  end

  defp read_json_body(%Plug.Conn{method: "GET"} = conn), do: {nil, conn}

  defp read_json_body(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(body), conn}
  end

  defp expect_daytona_start_sandbox(state \\ "started") do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/api/sandbox/sandbox_123/start"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      Req.Test.json(conn, %{"id" => "sandbox_123", "state" => state})
    end)
  end

  defp expect_daytona_clone_repository(exit_code \\ 0) do
    expect_daytona_clone_repository_with_command(clone_command(), exit_code)
  end

  defp expect_daytona_clone_repository_with_command(command, exit_code \\ 0) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/toolbox/sandbox_123/toolbox/process/execute"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "command" => command,
               "cwd" => ".",
               "timeout" => 300
             }

      Req.Test.json(conn, %{"exitCode" => exit_code, "result" => "git clone output"})
    end)
  end

  defp clone_command do
    "rm -rf workspace && git clone --depth 1 -- 'https://github.com/octocat/Hello-World' workspace"
  end

  defp tree_clone_command do
    [
      "rm -rf workspace",
      "git clone --depth 1 -- 'https://github.com/octocat/Hello-World' workspace",
      "cd workspace",
      "git fetch --depth 1 origin 'main'",
      "git checkout --detach FETCH_HEAD"
    ]
    |> Enum.join(" && ")
  end

  defp expect_daytona_install_dependencies(
         exit_code \\ 0,
         workspace_path \\ "workspace",
         result \\ "dependency install output"
       ) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/toolbox/sandbox_123/toolbox/process/execute"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "command" =>
                 logged_install_command(
                   dependency_install_command(workspace_path),
                   "dependency install",
                   true
                 ),
               "cwd" => ".",
               "timeout" => 600
             }

      Req.Test.json(conn, %{"exitCode" => exit_code, "result" => result})
    end)
  end

  defp dependency_install_command(workspace_path) do
    [
      dependency_install_cwd_command(workspace_path),
      package_manager_install_command(),
      maybe_build_frontman_astro_command()
    ]
    |> Enum.join(" && ")
  end

  defp dependency_install_cwd_command("workspace") do
    "cd workspace"
  end

  defp dependency_install_cwd_command(workspace_path) do
    package_json_path = "#{workspace_path}/package.json"

    [
      "if [ -f #{shell_quote(package_json_path)} ]; then cd #{shell_quote(workspace_path)};",
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

  defp logged_install_command(command, stage, reset_log?) do
    reset_command =
      case reset_log? do
        true -> ": > \"$log\""
        false -> "touch \"$log\""
      end

    [
      "log='/tmp/frontman-install.log'",
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

  defp compact_failure_tail(reason, max_length) do
    reason =
      reason
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    case String.length(reason) do
      length when length <= max_length -> reason
      length -> "..." <> String.slice(reason, length - max_length + 3, max_length - 3)
    end
  end

  defp expect_daytona_install_frontman(exit_code \\ 0) do
    expect_daytona_install_frontman(exit_code, "workspace")
  end

  defp expect_daytona_install_frontman(exit_code, cwd) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/toolbox/sandbox_123/toolbox/process/execute"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "command" =>
                 logged_install_command(
                   "npx astro add @frontman-ai/astro --yes",
                   "frontman install",
                   false
                 ),
               "cwd" => cwd,
               "timeout" => 300
             }

      Req.Test.json(conn, %{"exitCode" => exit_code, "result" => "astro add output"})
    end)
  end

  defp expect_daytona_check_workspace_path(workspace_path, exit_code \\ 0) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/toolbox/sandbox_123/toolbox/process/execute"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "command" => "test -d '#{workspace_path}'",
               "cwd" => ".",
               "timeout" => 300
             }

      Req.Test.json(conn, %{"exitCode" => exit_code, "result" => "path check output"})
    end)
  end

  defp expect_daytona_start_dev_server(cwd) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "POST"
      assert conn.request_path == "/api/toolbox/sandbox_123/toolbox/process/execute"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      command = Jason.decode!(body)["command"]

      assert command == dev_server_command()

      assert command =~
               ~r/pid=.*frontman-dev-server\.pid.*; log=.*frontman-dev-server\.log.*; if/

      assert Jason.decode!(body) == %{
               "command" => command,
               "cwd" => cwd,
               "timeout" => 10
             }

      Req.Test.json(conn, %{"exitCode" => 0, "result" => "dev server starting"})
    end)
  end

  defp expect_daytona_create_signed_preview_url do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/api/sandbox/sandbox_123/ports/4321/signed-preview-url"
      assert conn.query_string == "expiresInSeconds=3600"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      Req.Test.json(conn, %{"url" => "https://4321-preview.proxy.daytona.work"})
    end)
  end

  defp dev_server_command do
    script =
      [
        "pid='/tmp/frontman-dev-server.pid';",
        "log='/tmp/frontman-dev-server.log';",
        "if [ -f \"$pid\" ] && kill -0 \"$(cat \"$pid\")\" 2>/dev/null; then",
        "printf 'dev server already running pid %s\\n' \"$(cat \"$pid\")\";",
        "else",
        ": > \"$log\";",
        "(npm run dev -- --host 0.0.0.0 --port 4321 >> \"$log\" 2>&1 & echo $! > \"$pid\");",
        "sleep 2;",
        "if kill -0 \"$(cat \"$pid\")\" 2>/dev/null; then",
        "printf 'dev server starting pid %s\\n' \"$(cat \"$pid\")\";",
        "else cat \"$log\"; exit 1; fi; fi"
      ]
      |> Enum.join(" ")

    "sh -lc #{shell_quote(script)}"
  end

  defp expect_daytona_replace_labels("cloning") do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert %{
               "labels" => %{
                 "frontman.playgithub.clone_state" => "cloning",
                 "frontman.playgithub.clone_started_at" => clone_started_at,
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             } = Jason.decode!(body)

      assert {_, ""} = Integer.parse(clone_started_at)

      Req.Test.json(conn, %{})
    end)
  end

  defp expect_daytona_replace_labels("failed") do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "labels" => %{
                 "frontman.playgithub.clone_state" => "failed",
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             }

      Req.Test.json(conn, %{})
    end)
  end

  defp expect_daytona_replace_labels("cloned") do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "labels" => %{
                 "frontman.playgithub.cloned" => "true",
                 "frontman.playgithub.clone_state" => "cloned",
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             }

      Req.Test.json(conn, %{})
    end)
  end

  defp expect_daytona_replace_labels("clone_waiting_for_started") do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "labels" => %{
                 "frontman.playgithub.clone_state" => "waiting_for_started",
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             }

      Req.Test.json(conn, %{})
    end)
  end

  defp expect_daytona_replace_labels("install_waiting_for_started") do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "labels" => %{
                 "frontman.playgithub.cloned" => "true",
                 "frontman.playgithub.clone_state" => "cloned",
                 "frontman.playgithub.frontman_install_state" => "waiting_for_started",
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             }

      Req.Test.json(conn, %{})
    end)
  end

  defp expect_daytona_replace_labels(frontman_install_state)
       when frontman_install_state in ["installing", "installed", "install_failed"] do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      labels = Jason.decode!(body)["labels"]

      assert labels["frontman.playgithub.cloned"] == "true"
      assert labels["frontman.playgithub.clone_state"] == "cloned"
      assert labels["frontman.playgithub.frontman_install_state"] == frontman_install_state
      assert labels["frontman.playgithub.repo_url"] == "https://github.com/octocat/Hello-World"

      case frontman_install_state do
        "installing" ->
          install_started_at = labels["frontman.playgithub.frontman_install_started_at"]
          assert {_, ""} = Integer.parse(install_started_at)

        "install_failed" ->
          assert labels["frontman.playgithub.frontman_install_error"] == "astro add output"

        _frontman_install_state ->
          refute Map.has_key?(labels, "frontman.playgithub.frontman_install_started_at")
      end

      Req.Test.json(conn, %{})
    end)
  end

  defp expect_daytona_replace_install_failed_labels(error) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      assert Jason.decode!(body) == %{
               "labels" => %{
                 "frontman.playgithub.cloned" => "true",
                 "frontman.playgithub.clone_state" => "cloned",
                 "frontman.playgithub.frontman_install_error" => error,
                 "frontman.playgithub.frontman_install_state" => "install_failed",
                 "frontman.playgithub.repo_url" => "https://github.com/octocat/Hello-World"
               }
             }

      Req.Test.json(conn, %{})
    end)
  end

  defp expect_daytona_replace_dev_server_labels(dev_server_url) do
    Req.Test.expect(:playgithub_daytona, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert conn.method == "PUT"
      assert conn.request_path == "/api/sandbox/sandbox_123/labels"
      assert {"authorization", "Bearer test-daytona-key"} in conn.req_headers
      assert {"x-daytona-organization-id", "test-daytona-org"} in conn.req_headers

      labels = Jason.decode!(body)["labels"]

      assert labels["frontman.playgithub.cloned"] == "true"
      assert labels["frontman.playgithub.clone_state"] == "cloned"
      assert labels["frontman.playgithub.dev_server_port"] == "4321"
      assert labels["frontman.playgithub.dev_server_state"] == "starting"
      assert labels["frontman.playgithub.dev_server_url"] == dev_server_url
      assert labels["frontman.playgithub.frontman_install_state"] == "installed"
      assert labels["frontman.playgithub.repo_url"] == "https://github.com/octocat/Hello-World"

      started_at = labels["frontman.playgithub.dev_server_started_at"]
      assert {_, ""} = Integer.parse(started_at)

      Req.Test.json(conn, %{})
    end)
  end

  defp assert_response_lines(response, lines) do
    Enum.each(lines, fn line ->
      assert response =~ line
    end)
  end
end
