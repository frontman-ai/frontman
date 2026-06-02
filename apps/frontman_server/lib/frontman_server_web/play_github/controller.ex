# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.PlayGithub.Controller do
  @moduledoc """
  Handles authenticated PlayGithub host requests.
  """

  use FrontmanServerWeb, :controller

  alias FrontmanServer.PlayGithub
  alias FrontmanServer.PlayGithub.GithubReference
  alias FrontmanServerWeb.PlayGithub.SandboxProxy.Target

  @command_usage "?command=create|start|clone|install|dev"
  @frontman_install_log_path "/tmp/frontman-install.log"
  @dev_server_log_path "/tmp/frontman-dev-server.log"
  @dev_server_port 4321
  @dev_server_preview_expires_seconds 3_600

  def show(conn, %{"github_path" => []}) do
    html(conn, "PlayGithub local subdomain is routed")
  end

  def show(conn, %{"github_path" => github_path, "command" => raw_command} = params) do
    with {:parse_path, {:ok, parsed_path}} <-
           {:parse_path, GithubReference.parse_path(github_path)},
         {:parse_command, {:ok, command}} <- {:parse_command, parse_command(raw_command)} do
      show_parsed_path(conn, parsed_path, command, params)
    else
      {:parse_command, {:error, :missing_command}} ->
        handle_command_error(conn, :missing_command)

      {:parse_command, {:error, {:unsupported_command, command}}} ->
        handle_command_error(conn, {:unsupported_command, command})

      {:parse_path, {:error, reason}} ->
        conn
        |> put_status(:bad_request)
        |> text(format_error(reason))
    end
  end

  def show(conn, %{"github_path" => github_path}) do
    case GithubReference.parse_path(github_path) do
      {:ok, _parsed_path} ->
        html(conn, launch_page_html())

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> text(format_error(reason))
    end
  end

  defp show_parsed_path(conn, parsed_path, command, params) do
    case PlayGithub.run_repository_command(parsed_path, command, retry: retry?(params["retry"])) do
      {:ok, response} ->
        text(conn, format_repository_response(conn, response))

      {:error, reason, status, body} ->
        handle_playgithub_error(conn, parsed_path, {reason, status, body})

      {:error, reason, body} ->
        handle_playgithub_error(conn, parsed_path, {reason, body})

      {:error, reason} ->
        handle_playgithub_error(conn, parsed_path, reason)
    end
  end

  defp parse_command("create"), do: {:ok, :create}
  defp parse_command("start"), do: {:ok, :start}
  defp parse_command("clone"), do: {:ok, :clone}
  defp parse_command("install"), do: {:ok, :install}
  defp parse_command("dev"), do: {:ok, :dev}
  defp parse_command(nil), do: {:error, :missing_command}

  defp parse_command(command) when is_binary(command),
    do: {:error, {:unsupported_command, command}}

  defp retry?(retry) when retry in ["true", "1"], do: true
  defp retry?(_retry), do: false

  defp handle_command_error(conn, :missing_command) do
    conn
    |> put_status(:bad_request)
    |> text("error: missing_command\nusage: #{@command_usage}")
  end

  defp handle_command_error(conn, {:unsupported_command, command}) do
    conn
    |> put_status(:bad_request)
    |> text("error: unsupported_command\ncommand: #{command}\nusage: #{@command_usage}")
  end

  defp handle_playgithub_error(conn, _parsed_path, :not_repository_path) do
    conn
    |> put_status(:bad_request)
    |> text("error: not_repository_path")
  end

  defp handle_playgithub_error(conn, _parsed_path, :daytona_sandbox_not_found) do
    conn
    |> put_status(:not_found)
    |> text("error: daytona_sandbox_not_found\nnext: ?command=create")
  end

  defp handle_playgithub_error(conn, _parsed_path, :repository_not_cloned) do
    conn
    |> put_status(:conflict)
    |> text("error: repository_not_cloned\nnext: ?command=clone")
  end

  defp handle_playgithub_error(conn, _parsed_path, :frontman_not_installed) do
    conn
    |> put_status(:conflict)
    |> text("error: frontman_not_installed\nnext: ?command=install")
  end

  defp handle_playgithub_error(conn, _parsed_path, {:malformed_daytona_response, body}) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_create_malformed_response\nbody: #{inspect(body)}")
  end

  defp handle_playgithub_error(conn, _parsed_path, {:daytona_create_failed, status, body}) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_create_failed\nstatus: #{status}\nbody: #{inspect(body)}")
  end

  defp handle_playgithub_error(conn, _parsed_path, {:daytona_start_failed, status, body}) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_start_failed\nstatus: #{status}\nbody: #{inspect(body)}")
  end

  defp handle_playgithub_error(conn, _parsed_path, {:daytona_clone_failed, status, body}) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_clone_failed\nstatus: #{status}\nbody: #{inspect(body)}")
  end

  defp handle_playgithub_error(
         conn,
         _parsed_path,
         {:daytona_frontman_install_failed, status, body}
       ) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_frontman_install_failed\nstatus: #{status}\nbody: #{inspect(body)}")
  end

  defp handle_playgithub_error(conn, _parsed_path, {:daytona_frontman_install_failed, body}) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_frontman_install_failed\nbody: #{inspect(body)}")
  end

  defp handle_playgithub_error(conn, _parsed_path, {:daytona_dev_server_failed, status, body}) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_dev_server_failed\nstatus: #{status}\nbody: #{inspect(body)}")
  end

  defp handle_playgithub_error(conn, _parsed_path, {:daytona_preview_url_failed, status, body}) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_preview_url_failed\nstatus: #{status}\nbody: #{inspect(body)}")
  end

  defp handle_playgithub_error(conn, _parsed_path, {:daytona_get_failed, status, body}) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_get_failed\nstatus: #{status}\nbody: #{inspect(body)}")
  end

  defp handle_playgithub_error(conn, _parsed_path, {:daytona_label_failed, status, body}) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_label_failed\nstatus: #{status}\nbody: #{inspect(body)}")
  end

  defp handle_playgithub_error(conn, _parsed_path, {:daytona_repo_label_mismatch, labels}) do
    conn
    |> put_status(:conflict)
    |> text("error: daytona_repo_label_mismatch\nlabels: #{inspect(labels)}")
  end

  defp handle_playgithub_error(conn, _parsed_path, reason) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_request_failed\nreason: #{inspect(reason)}")
  end

  defp format_repository_response(conn, %{command: command, sandbox: sandbox}) do
    github_reference = sandbox.github_reference

    [
      "command: #{command}",
      "repository_url: #{GithubReference.repository_url(github_reference)}",
      format_optional_field("branch", GithubReference.branch(github_reference)),
      format_optional_field("repository_path", GithubReference.repository_path(github_reference)),
      "workspace_path: #{PlayGithub.workspace_path(github_reference)}",
      "sandbox_name: #{sandbox.name}",
      "sandbox_id: #{sandbox.id}",
      "provider_state: #{Atom.to_string(sandbox.provider_state)}",
      "lifecycle: #{Atom.to_string(sandbox.lifecycle)}",
      format_lifecycle_error(sandbox),
      format_frontman_install_log_path(command),
      format_dev_server_port(command),
      format_dev_server_log_path(command),
      format_optional_field("dev_server_url", sandbox.dev_server_url),
      format_dev_server_url_expires_in_seconds(sandbox),
      format_frontman_preview_url(conn, sandbox),
      "next: #{next_step(sandbox)}"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp format_optional_field(_field, nil), do: nil
  defp format_optional_field(field, value), do: "#{field}: #{value}"

  defp format_lifecycle_error(sandbox) do
    case sandbox.lifecycle_error do
      nil -> nil
      "" -> nil
      error -> "lifecycle_error: #{error}"
    end
  end

  defp format_frontman_install_log_path("install"),
    do: "frontman_install_log: #{@frontman_install_log_path}"

  defp format_frontman_install_log_path(_command), do: nil

  defp format_dev_server_port("dev"), do: "dev_server_port: #{@dev_server_port}"
  defp format_dev_server_port(_command), do: nil

  defp format_dev_server_log_path("dev"), do: "dev_server_log: #{@dev_server_log_path}"
  defp format_dev_server_log_path(_command), do: nil

  defp format_dev_server_url_expires_in_seconds(sandbox) do
    case sandbox.dev_server_url do
      nil -> nil
      _url -> "dev_server_url_expires_in_seconds: #{@dev_server_preview_expires_seconds}"
    end
  end

  defp format_frontman_preview_url(conn, sandbox) do
    case sandbox.dev_server_url do
      nil -> nil
      dev_server_url -> format_frontman_preview_url_for_url(conn, dev_server_url)
    end
  end

  defp next_step(%{provider_state: :starting}), do: "wait_for_daytona_start"
  defp next_step(%{lifecycle: :sandbox_created}), do: "?command=clone"
  defp next_step(%{lifecycle: :sandbox_starting}), do: "wait_for_daytona_start"
  defp next_step(%{lifecycle: :clone_starting}), do: "wait_for_clone"
  defp next_step(%{lifecycle: :clone_failed}), do: "?command=clone"
  defp next_step(%{lifecycle: :clone_finished}), do: "?command=install"
  defp next_step(%{lifecycle: :install_starting}), do: "wait_for_install"
  defp next_step(%{lifecycle: :install_failed}), do: "?command=install&retry=true"
  defp next_step(%{lifecycle: :install_finished}), do: "?command=dev"
  defp next_step(%{lifecycle: :dev_server_starting}), do: "wait_for_dev_server"
  defp next_step(%{lifecycle: :dev_server_started}), do: "open_frontman_preview"
  defp next_step(%{lifecycle: :dev_server_failed}), do: "?command=dev"

  defp format_frontman_preview_url_for_url(conn, dev_server_url) do
    query = URI.encode_query(%{"url" => dev_server_url}, :rfc3986)
    "frontman_preview_url: #{request_origin(conn)}/sandbox?#{query}"
  end

  defp request_origin(conn) do
    Target.request_origin(conn)
  end

  defp format_error(:missing_owner_or_repo), do: "error: missing_owner_or_repo"
  defp format_error(:missing_tree_ref), do: "error: missing_tree_ref"
  defp format_error(:invalid_issue_number), do: "error: invalid_issue_number"

  defp format_error({:unsupported_github_path, segments}) do
    "error: unsupported_github_path\nsegments: #{Enum.join(segments, "/")}"
  end

  defp launch_page_html do
    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Launching PlayGithub</title>
        <style>
          body { font-family: system-ui, sans-serif; margin: 2rem; max-width: 48rem; }
          pre { background: #111827; color: #e5e7eb; overflow: auto; padding: 1rem; }
        </style>
      </head>
      <body>
        <h1>Launching PlayGithub sandbox</h1>
        <p id="status">Preparing Daytona sandbox...</p>
        <pre id="log" aria-live="polite"></pre>
        <script>
          (() => {
            const devServerPort = #{PlayGithub.dev_server_port()};
            const maxAttempts = 240;
            const log = document.getElementById("log");
            const status = document.getElementById("status");

            const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

            const commandUrl = (command, retry) => {
              const url = new URL(window.location.href);
              url.searchParams.set("command", command);

              if (retry) {
                url.searchParams.set("retry", "true");
              } else {
                url.searchParams.delete("retry");
              }

              return url;
            };

            const parseResponse = (body) => {
              const data = {};

              for (const line of body.split("\\n")) {
                const separator = line.indexOf(": ");

                if (separator > 0) {
                  data[line.slice(0, separator)] = line.slice(separator + 2);
                }
              }

              return data;
            };

            const appendLog = (command, body) => {
              log.textContent = `${log.textContent}\\n$ ${command}\\n${body}\\n`;
              log.scrollTop = log.scrollHeight;
            };

            const sandboxUrl = (sandboxId) => {
              const url = new URL(window.location.href);
              url.hostname = `${sandboxId}-${devServerPort}.${url.hostname}`;
              url.pathname = "/";
              url.search = "";
              url.hash = "";
              return url.toString();
            };

            const commandFromNext = (next) => {
              const params = new URLSearchParams(next.startsWith("?") ? next.slice(1) : next);
              const command = params.get("command");
              if (!command) return null;

              return {command, retry: params.get("retry") === "true"};
            };

            const waitCommand = (next, command) => {
              if (next === "wait_for_daytona_start") return command === "create" ? "start" : command;
              if (next === "wait_for_clone") return "clone";
              if (next === "wait_for_install") return "install";
              if (next === "wait_for_dev_server") return "dev";
              return command;
            };

            const waitMs = (next) => {
              if (next === "wait_for_install") return 5000;
              if (next === "wait_for_clone") return 3000;
              return 2500;
            };

            const nextStep = (data, command, state) => {
              if (data.next === "open_frontman_preview" && data.sandbox_id) {
                return {redirect: sandboxUrl(data.sandbox_id)};
              }

              if (data.next && data.next.startsWith("?command=")) {
                const next = commandFromNext(data.next);

                if (next && next.command === "install" && next.retry) {
                  if (!state.retriedInstallFailure) {
                    state.retriedInstallFailure = true;
                    return {command: "install", retry: true, wait: 0};
                  }

                  throw new Error(data.lifecycle_error || "Frontman install failed");
                }

                if (next) return {...next, wait: 0};
              }

              if (data.next && data.next.startsWith("wait_for_")) {
                return {command: waitCommand(data.next, command), wait: waitMs(data.next)};
              }

              if (data.error === "daytona_sandbox_not_found") return {command: "create", wait: 0};
              if (data.error === "repository_not_cloned") return {command: "clone", wait: 0};
              if (data.error === "frontman_not_installed") return {command: "install", wait: 0};

              throw new Error(data.error || "Unknown PlayGithub launch state");
            };

            const runCommand = async (command, retry) => {
              status.textContent = `Running ${command}${retry ? " with retry" : ""}...`;
              const response = await fetch(commandUrl(command, retry), {headers: {accept: "text/html"}});

              if (response.redirected) {
                window.location.href = response.url;
                return null;
              }

              const body = await response.text();
              appendLog(`${command}${retry ? " --retry" : ""}`, body);
              return parseResponse(body);
            };

            const launch = async () => {
              let command = "create";
              let retry = false;
              const state = {retriedInstallFailure: false};

              for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
                const data = await runCommand(command, retry);
                if (!data) return;

                const step = nextStep(data, command, state);

                if (step.redirect) {
                  status.textContent = "Opening sandbox preview...";
                  window.location.href = step.redirect;
                  return;
                }

                command = step.command;
                retry = Boolean(step.retry);

                if (step.wait > 0) {
                  status.textContent = `Waiting for ${command}...`;
                  await sleep(step.wait);
                }
              }

              throw new Error("Timed out launching PlayGithub sandbox");
            };

            launch().catch((error) => {
              status.textContent = `Launch failed: ${error.message}`;
            });
          })();
        </script>
      </body>
    </html>
    """
  end
end
