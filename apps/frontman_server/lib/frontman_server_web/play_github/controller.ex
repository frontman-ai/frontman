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

  @command_usage "?command=create|start|clone|install|dev"

  def show(conn, %{"github_path" => []}) do
    html(conn, "PlayGithub local subdomain is routed")
  end

  def show(conn, %{"github_path" => github_path, "command" => raw_command} = params) do
    with {:parse_path, {:ok, parsed_path}} <-
           {:parse_path, GithubReference.parse_path(github_path)},
         {:parse_command, {:ok, command}} <- {:parse_command, parse_command(raw_command)} do
      show_parsed_path(conn, parsed_path, command, params)
    else
      {:parse_command, {:error, reason}} ->
        render_text(conn, command_error(reason))

      {:parse_path, {:error, reason}} ->
        render_text(conn, {:bad_request, format_path_error(reason)})
    end
  end

  def show(conn, %{"github_path" => github_path}) do
    case GithubReference.parse_path(github_path) do
      {:ok, _parsed_path} -> html(conn, launch_page_html())
      {:error, reason} -> render_text(conn, {:bad_request, format_path_error(reason)})
    end
  end

  defp show_parsed_path(conn, parsed_path, command, params) do
    conn.assigns.current_scope
    |> PlayGithub.run_repository_command(parsed_path, command, retry: retry?(params["retry"]))
    |> command_result(parsed_path)
    |> render_command_result(conn)
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

  defp command_error(:missing_command) do
    {:bad_request, "error: missing_command\nusage: #{@command_usage}"}
  end

  defp command_error({:unsupported_command, command}) do
    {:bad_request, "error: unsupported_command\ncommand: #{command}\nusage: #{@command_usage}"}
  end

  defp command_result({:ok, response}, github_reference) do
    {:ok, format_repository_response(response, github_reference)}
  end

  defp command_result({:error, reason, status, body}, _github_reference) do
    playgithub_error({reason, status, body})
  end

  defp command_result({:error, reason, body}, _github_reference) do
    playgithub_error({reason, body})
  end

  defp command_result({:error, reason}, _github_reference) do
    playgithub_error(reason)
  end

  defp render_command_result({:ok, body}, conn), do: text(conn, body)
  defp render_command_result({status, body}, conn), do: render_text(conn, {status, body})

  defp render_text(conn, {status, body}) do
    conn
    |> put_status(status)
    |> text(body)
  end

  defp playgithub_error(:not_repository_path), do: {:bad_request, "error: not_repository_path"}

  defp playgithub_error(:daytona_sandbox_not_found) do
    {:not_found, "error: daytona_sandbox_not_found\nnext: ?command=create"}
  end

  defp playgithub_error(:repository_not_cloned) do
    {:conflict, "error: repository_not_cloned\nnext: ?command=clone"}
  end

  defp playgithub_error(:frontman_not_installed) do
    {:conflict, "error: frontman_not_installed\nnext: ?command=install"}
  end

  defp playgithub_error({reason, status, body}) when is_atom(reason) do
    {:bad_gateway, "error: #{reason}\nstatus: #{status}\nbody: #{inspect(body)}"}
  end

  defp playgithub_error({reason, body}) when is_atom(reason) do
    {:bad_gateway, "error: #{reason}\nbody: #{inspect(body)}"}
  end

  defp playgithub_error(reason) do
    {:bad_gateway, "error: daytona_request_failed\nreason: #{inspect(reason)}"}
  end

  defp format_repository_response(%{command: command, sandbox: sandbox}, github_reference) do
    [
      "command: #{command}",
      "repository_url: #{GithubReference.repository_url(github_reference)}",
      format_optional_field("branch", GithubReference.branch(github_reference)),
      format_optional_field("repository_path", GithubReference.repository_path(github_reference)),
      "workspace_path: #{PlayGithub.workspace_path(github_reference)}",
      "sandbox_id: #{sandbox.daytona_sandbox_id}",
      "status: #{Atom.to_string(sandbox.status)}",
      format_status_error(sandbox),
      "next: #{next_step(sandbox)}"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp format_optional_field(_field, nil), do: nil
  defp format_optional_field(field, value), do: "#{field}: #{value}"

  defp format_status_error(sandbox) do
    case sandbox.status_error do
      nil -> nil
      "" -> nil
      error -> "status_error: #{error}"
    end
  end

  defp next_step(%{status: status}) do
    case status do
      # :sandbox_creating -> "wait_for_sandbox_create"
      # :sandbox_create_failed -> "?command=create&retry=true"
      # :sandbox_created -> "?command=clone"
      # :clone_starting -> "wait_for_clone"
      # :clone_failed -> "?command=clone"
      # :clone_finished -> "?command=install"
      # :install_starting -> "wait_for_install"
      # :install_failed -> "?command=install&retry=true"
      # :install_finished -> "?command=dev"
      # :dev_server_starting -> "wait_for_dev_server"
      # :dev_server_started -> "open_frontman_preview"
      :dev_server_failed -> "?command=dev"
    end
  end

  defp format_path_error(:missing_owner_or_repo), do: "error: missing_owner_or_repo"
  defp format_path_error(:missing_tree_ref), do: "error: missing_tree_ref"
  defp format_path_error(:invalid_issue_number), do: "error: invalid_issue_number"

  defp format_path_error({:unsupported_github_path, segments}) do
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
              if (next === "wait_for_sandbox_create") return "create";
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

                  throw new Error(data.status_error || "Frontman install failed");
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
