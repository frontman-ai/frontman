# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServerWeb.UserApiKeyController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Providers

  @doc """
  Lists saved provider API key metadata for the current user without exposing key values.
  """
  def index(conn, _params) do
    scope = conn.assigns.current_scope

    json(conn, %{"providers" => Providers.list_api_key_providers(scope)})
  end

  @doc """
  Stores a provider API key for the current user.
  """
  def create(conn, %{"provider" => provider, "key" => key}) do
    scope = conn.assigns.current_scope

    case Providers.upsert_api_key(scope, provider, key) do
      :ok ->
        json(conn, %{status: "ok", provider: provider})

      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: errors})
    end
  end
end
