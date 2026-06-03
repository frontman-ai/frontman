# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule Daytona.Toolbox do
  @moduledoc false

  alias Daytona

  @schema Zoi.struct(
            __MODULE__,
            %{
              daytona: Zoi.any() |> Zoi.optional(),
              proxyToolboxUrl:
                Zoi.url(typespec: quote(do: URI.t()))
                |> Zoi.transform(&URI.parse/1)
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @spec fetch(Daytona.t()) :: {:ok, t()} | {:error, term()}
  def fetch(%Daytona{} = daytona) do
    with {:ok, %Req.Response{status: status, body: body}} when status in 200..299 <-
           daytona |> Daytona.app_request() |> Req.get(url: "/config"),
         {:ok, toolbox} <- Zoi.parse(@schema, body) do
      {:ok, %{toolbox | daytona: daytona}}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:daytona_config_failed, status, body}}

      {:error, [%Zoi.Error{} | _] = errors} ->
        {:error, {:malformed_daytona_config, Zoi.prettify_errors(errors)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def request(
        %__MODULE__{daytona: %Daytona{} = daytona, proxyToolboxUrl: proxy_toolbox_url},
        sandbox_id
      )
      when is_binary(sandbox_id) do
    daytona
    |> Daytona.app_request()
    |> Req.merge(base_url: toolbox_base_url(proxy_toolbox_url, sandbox_id))
  end

  defp toolbox_base_url(%URI{} = proxy_toolbox_url, sandbox_id) do
    proxy_toolbox_url
    |> URI.append_path("/#{sandbox_id}")
    |> URI.to_string()
  end
end
