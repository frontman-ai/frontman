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

  def execute_command(sandbox_id, command, opts \\ [])
      when is_binary(sandbox_id) and is_binary(command) do
    timeout_seconds = Keyword.get(opts, :timeout_seconds, 300)

    Req.post(
      "#{app_api_url()}/toolbox/#{sandbox_id}/toolbox/process/execute",
      [
        auth: {:bearer, api_key()},
        headers: daytona_headers(),
        json: %{
          command: command,
          cwd: Keyword.get(opts, :cwd, "workspace"),
          timeout: timeout_seconds
        },
        receive_timeout: timeout_seconds * 1_000 + 5_000
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
    config() |> Keyword.get(:app_api_url, @default_app_api_url)
  end

  defp api_key do
    config() |> Keyword.fetch!(:api_key)
  end

  defp daytona_headers do
    [{"x-daytona-organization-id", organization_id()}]
  end

  defp organization_id do
    config() |> Keyword.fetch!(:organization_id)
  end

  defp req_options do
    config() |> Keyword.get(:req_options, [])
  end

  defp config do
    :frontman_server
    |> Application.fetch_env!(:playgithub)
    |> Keyword.fetch!(:daytona)
  end
end
