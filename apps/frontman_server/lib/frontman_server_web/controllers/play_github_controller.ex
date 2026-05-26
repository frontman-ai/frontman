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
        text(conn, PlayGithub.format_path(parsed_path))

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> text(format_error(reason))
    end
  end

  defp format_error(:missing_owner_or_repo), do: "error: missing_owner_or_repo"
  defp format_error(:missing_tree_ref), do: "error: missing_tree_ref"
  defp format_error(:invalid_issue_number), do: "error: invalid_issue_number"

  defp format_error({:unsupported_github_path, segments}) do
    "error: unsupported_github_path\nsegments: #{Enum.join(segments, "/")}"
  end
end
