# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.PlayGithub.Daytona.Client do
  @moduledoc false

  @default_app_api_url "https://app.daytona.io/api"
  @schema Zoi.struct(__MODULE__, %{proxyToolboxUrl: Zoi.string() |> Zoi.gte(1)}, coerce: true)

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def new do
    with {:ok, %Req.Response{status: status, body: body}} when status in 200..299 <-
           app_request() |> Req.get(url: "/config"),
         {:ok, client} <- Zoi.parse(@schema, body) do
      {:ok, client}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:daytona_config_failed, status, body}}

      {:error, [%Zoi.Error{} | _] = errors} ->
        {:error, {:malformed_daytona_config, Zoi.prettify_errors(errors)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def toolbox_request(%__MODULE__{proxyToolboxUrl: proxy_toolbox_url}, sandbox_id)
      when is_binary(sandbox_id) do
    app_request()
    |> Req.merge(base_url: toolbox_base_url(proxy_toolbox_url, sandbox_id))
  end

  def app_request do
    [base_url: app_api_url(), auth: {:bearer, api_key()}, headers: daytona_headers()]
    |> Req.new()
    |> Req.merge(req_options())
  end

  defp app_api_url do
    config() |> Keyword.get(:app_api_url, @default_app_api_url)
  end

  defp toolbox_base_url(proxy_toolbox_url, sandbox_id) do
    proxy_toolbox_url = String.trim_trailing(proxy_toolbox_url, "/")

    "#{proxy_toolbox_url}/#{sandbox_id}"
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
