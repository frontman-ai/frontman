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

  def show(conn, %{"github_path" => github_path} = params) do
    with {:ok, parsed_path} <- GithubReference.parse_path(github_path),
         {:ok, command} <- parse_command(params["command"]) do
      show_parsed_path(conn, parsed_path, command, params)
    else
      {:error, :missing_command} ->
        handle_command_error(conn, :missing_command)

      {:error, {:unsupported_command, command}} ->
        handle_command_error(conn, {:unsupported_command, command})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> text(format_error(reason))
    end
  end

  defp show_parsed_path(conn, parsed_path, command, params) do
    case PlayGithub.run_repository_command(parsed_path, command, retry: retry?(params["retry"])) do
      {:ok, response} ->
        text(conn, format_daytona_response(conn, response))

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

  defp handle_playgithub_error(conn, parsed_path, :not_repository_path) do
    text(conn, GithubReference.format(parsed_path))
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

  defp format_daytona_response(conn, response) do
    [
      "command: #{response.command}",
      "repo_url: #{response.repo_url}",
      format_optional_field("github_ref", response.github_ref),
      format_optional_field("repo_path", response.repo_path),
      "workspace_path: #{response.workspace_path}",
      "sandbox_name: #{response.sandbox_name}",
      "sandbox_id: #{response.sandbox_id}",
      "sandbox_state: #{response.sandbox_state}",
      "sandbox_reused: #{response.sandbox_reused}",
      "clone_state: #{response.clone_state}",
      "frontman_install_state: #{response.frontman_install_state}",
      format_frontman_install_error(response.frontman_install_error),
      format_frontman_install_log_path(response),
      format_dev_server_state(response),
      format_optional_field("dev_server_port", response.dev_server_port),
      format_dev_server_log_path(response),
      format_optional_field("dev_server_url", response.dev_server_url),
      format_optional_field(
        "dev_server_url_expires_in_seconds",
        response.dev_server_url_expires_in_seconds
      ),
      format_frontman_preview_url(conn, response),
      format_dev_server_error(response.dev_server_error),
      "next: #{next_step(response)}"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp format_frontman_install_error(nil), do: nil
  defp format_frontman_install_error(""), do: nil

  defp format_frontman_install_error(frontman_install_error) do
    "frontman_install_error: #{frontman_install_error}"
  end

  defp format_optional_field(_field, nil), do: nil
  defp format_optional_field(field, value), do: "#{field}: #{value}"

  defp format_frontman_install_log_path(%{
         command: "install",
         frontman_install_log_path: log_path
       }) do
    "frontman_install_log: #{log_path}"
  end

  defp format_frontman_install_log_path(_response), do: nil

  defp format_dev_server_state(%{dev_server_state: nil}), do: nil
  defp format_dev_server_state(%{dev_server_state: state}), do: "dev_server_state: #{state}"

  defp format_dev_server_log_path(%{command: "dev", dev_server_log_path: log_path}) do
    "dev_server_log: #{log_path}"
  end

  defp format_dev_server_log_path(_response), do: nil

  defp format_frontman_preview_url(_conn, %{dev_server_url: nil}), do: nil

  defp format_frontman_preview_url(conn, %{dev_server_url: dev_server_url}) do
    query = URI.encode_query(%{"url" => dev_server_url}, :rfc3986)
    "frontman_preview_url: #{request_origin(conn)}/sandbox?#{query}"
  end

  defp format_dev_server_error(nil), do: nil
  defp format_dev_server_error(""), do: nil
  defp format_dev_server_error(error), do: "dev_server_error: #{error}"

  defp next_step(%{command: "dev", dev_server_state: "starting"}), do: "open_frontman_preview"
  defp next_step(%{sandbox_state: "started"}), do: "open_frontman_editor"
  defp next_step(%{sandbox_state: "starting"}), do: "wait_for_daytona_start"
  defp next_step(_response), do: "start_daytona_sandbox"

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
