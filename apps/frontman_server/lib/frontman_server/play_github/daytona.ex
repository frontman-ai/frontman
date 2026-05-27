# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.Daytona do
  @moduledoc false

  @default_app_api_url "https://app.daytona.io/api"

  def create_sandbox(json \\ %{}) do
    Req.post(
      "#{app_api_url()}/sandbox",
      [
        auth: {:bearer, api_key()},
        headers: daytona_headers(),
        json: json
      ] ++ req_options()
    )
  end

  def get_sandbox(sandbox_id) do
    Req.get(
      "#{app_api_url()}/sandbox/#{sandbox_id}",
      [auth: {:bearer, api_key()}, headers: daytona_headers()] ++ req_options()
    )
  end

  def clone_repository(sandbox_id, repo_url) do
    Req.post(
      "#{app_api_url()}/toolbox/#{sandbox_id}/toolbox/git/clone",
      [
        auth: {:bearer, api_key()},
        headers: daytona_headers(),
        json: %{url: repo_url, path: "workspace"}
      ] ++ req_options()
    )
  end

  def replace_labels(sandbox_id, labels) do
    Req.put(
      "#{app_api_url()}/sandbox/#{sandbox_id}/labels",
      [auth: {:bearer, api_key()}, headers: daytona_headers(), json: %{labels: labels}] ++
        req_options()
    )
  end

  defp app_api_url do
    Application.get_env(
      :frontman_server,
      :playgithub_daytona_app_api_url,
      @default_app_api_url
    )
  end

  defp api_key do
    Application.fetch_env!(:frontman_server, :playgithub_daytona_api_key)
  end

  defp daytona_headers do
    [{"x-daytona-organization-id", organization_id()}]
  end

  defp organization_id do
    Application.fetch_env!(:frontman_server, :playgithub_daytona_organization_id)
  end

  defp req_options do
    Application.get_env(:frontman_server, :playgithub_daytona_req_options, [])
  end
end
