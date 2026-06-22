# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule Daytona do
  @moduledoc false

  use Boundary, exports: [Sandbox, Toolbox, Toolbox.Git, Toolbox.Process]
  @enforce_keys [:app_api_url, :api_key, :organization_id]
  defstruct [:app_api_url, :api_key, :organization_id, req_options: []]

  def new do
    config = config()

    %__MODULE__{
      app_api_url: Keyword.fetch!(config, :app_api_url),
      api_key: Keyword.fetch!(config, :api_key),
      organization_id: Keyword.fetch!(config, :organization_id),
      req_options: Keyword.get(config, :req_options, [])
    }
  end

  def app_request(%__MODULE__{
        app_api_url: app_api_url,
        api_key: api_key,
        organization_id: organization_id,
        req_options: req_options
      }) do
    [
      base_url: app_api_url,
      auth: {:bearer, api_key},
      headers: [{"x-daytona-organization-id", organization_id}]
    ]
    |> Req.new()
    |> Req.merge(req_options)
  end

  defp config do
    Application.fetch_env!(:frontman_server, __MODULE__)
  end
end
