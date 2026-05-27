# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.PlayGithubController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.PlayGithub

  def index(conn, _params) do
    html(
      conn,
      "PlayGithub local subdomain is routed for #{conn.assigns.current_scope.user.email}"
    )
  end

  def show(conn, %{"github_path" => github_path}) do
    case PlayGithub.parse_path(github_path) do
      {:ok, parsed_path} ->
        show_parsed_path(conn, parsed_path)

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> text(format_error(reason))
    end
  end

  defp show_parsed_path(conn, parsed_path) do
    case PlayGithub.get_or_create_repository_sandbox(parsed_path) do
      {:ok,
       %{
         repo_url: repo_url,
         clone_state: clone_state,
         sandbox_id: sandbox_id,
         sandbox_name: sandbox_name,
         sandbox_reused: sandbox_reused,
         sandbox_state: sandbox_state
       }} ->
        text(
          conn,
          format_daytona_response(
            repo_url,
            clone_state,
            sandbox_id,
            sandbox_name,
            sandbox_reused,
            sandbox_state
          )
        )

      {:error, reason, status, body} ->
        handle_playgithub_error(conn, parsed_path, {reason, status, body})

      {:error, reason, body} ->
        handle_playgithub_error(conn, parsed_path, {reason, body})

      {:error, reason} ->
        handle_playgithub_error(conn, parsed_path, reason)
    end
  end

  defp handle_playgithub_error(conn, parsed_path, :not_repository_path) do
    text(conn, PlayGithub.format_path(parsed_path))
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

  defp handle_playgithub_error(conn, _parsed_path, {:daytona_clone_failed, status, body}) do
    conn
    |> put_status(:bad_gateway)
    |> text("error: daytona_clone_failed\nstatus: #{status}\nbody: #{inspect(body)}")
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
    |> text("error: daytona_create_failed\nreason: #{inspect(reason)}")
  end

  defp format_daytona_response(
         repo_url,
         clone_state,
         sandbox_id,
         sandbox_name,
         sandbox_reused,
         sandbox_state
       ) do
    [
      "repo_url: #{repo_url}",
      "sandbox_name: #{sandbox_name}",
      "sandbox_id: #{sandbox_id}",
      "sandbox_state: #{sandbox_state}",
      "sandbox_reused: #{sandbox_reused}",
      "clone_state: #{clone_state}",
      "next: open_frontman_editor"
    ]
    |> Enum.join("\n")
  end

  defp format_error(:missing_owner_or_repo), do: "error: missing_owner_or_repo"
  defp format_error(:missing_tree_ref), do: "error: missing_tree_ref"
  defp format_error(:invalid_issue_number), do: "error: invalid_issue_number"

  defp format_error({:unsupported_github_path, segments}) do
    "error: unsupported_github_path\nsegments: #{Enum.join(segments, "/")}"
  end
end
