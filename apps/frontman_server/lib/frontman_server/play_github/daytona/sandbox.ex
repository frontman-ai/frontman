# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.Daytona.Sandbox do
  @moduledoc false

  alias FrontmanServer.PlayGithub.Daytona.Client
  alias FrontmanServer.PlayGithub.Daytona.Sandbox.CreateSandbox

  def create(%CreateSandbox{} = sandbox) do
    Client.app_request()
    |> Req.post(url: "/sandbox", json: sandbox)
  end

  def get(sandbox_id) when is_binary(sandbox_id) do
    Client.app_request()
    |> Req.get(url: "/sandbox/:sandbox_id", path_params: [sandbox_id: sandbox_id])
  end

  def start(sandbox_id) when is_binary(sandbox_id) do
    Client.app_request()
    |> Req.post(url: "/sandbox/:sandbox_id/start", path_params: [sandbox_id: sandbox_id])
  end

  def get_signed_preview_url(sandbox_id, port, expires_seconds)
      when is_binary(sandbox_id) and is_integer(port) and is_integer(expires_seconds) do
    Client.app_request()
    |> Req.get(
      url: "/sandbox/:sandbox_id/ports/:port/signed-preview-url",
      path_params: [sandbox_id: sandbox_id, port: port],
      params: [expiresInSeconds: expires_seconds]
    )
  end

  def get_preview_link(sandbox_id, port) when is_binary(sandbox_id) and is_integer(port) do
    Client.app_request()
    |> Req.get(
      url: "/sandbox/:sandbox_id/ports/:port/preview-url",
      path_params: [sandbox_id: sandbox_id, port: port]
    )
  end

  def replace_labels(sandbox_id, labels) when is_binary(sandbox_id) and is_map(labels) do
    Client.app_request()
    |> Req.put(
      url: "/sandbox/:sandbox_id/labels",
      path_params: [sandbox_id: sandbox_id],
      json: %{labels: labels}
    )
  end
end
