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
  @frontman_install_log_path "/tmp/frontman-install.log"
  @dev_server_log_path "/tmp/frontman-dev-server.log"
  @dev_server_port 4321
  @dev_server_preview_expires_seconds 3_600

  def show(conn, %{"github_path" => github_path} = params) do
    with {:parse_path, {:ok, parsed_path}} <-
           {:parse_path, GithubReference.parse_path(github_path)},
         {:parse_command, {:ok, command}} <- {:parse_command, parse_command(params["command"])},
         {:run_command, _parsed_path, {:ok, response}} <-
           {:run_command, parsed_path,
            PlayGithub.run_repository_command(parsed_path, command,
              retry: retry?(params["retry"])
            )} do
      text(conn, format_repository_response(conn, response))
    else
      {:run_command, parsed_path, {:error, reason, status, body}} ->
        handle_playgithub_error(conn, parsed_path, {reason, status, body})

      {:run_command, parsed_path, {:error, reason, body}} ->
        handle_playgithub_error(conn, parsed_path, {reason, body})

      {:run_command, parsed_path, {:error, reason}} ->
        handle_playgithub_error(conn, parsed_path, reason)

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
      "workspace_path: #{GithubReference.workspace_path(github_reference)}",
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
    scheme = Atom.to_string(conn.scheme)

    case default_port?(conn.scheme, conn.port) do
      true -> scheme <> "://" <> conn.host
      false -> scheme <> "://" <> conn.host <> ":" <> Integer.to_string(conn.port)
    end
  end

  defp default_port?(:http, 80), do: true
  defp default_port?(:https, 443), do: true
  defp default_port?(_scheme, _port), do: false

  defp format_error(:missing_owner_or_repo), do: "error: missing_owner_or_repo"
  defp format_error(:missing_tree_ref), do: "error: missing_tree_ref"
  defp format_error(:invalid_issue_number), do: "error: invalid_issue_number"

  defp format_error({:unsupported_github_path, segments}) do
    "error: unsupported_github_path\nsegments: #{Enum.join(segments, "/")}"
  end
end
