# Frontman Server
# Copyright (C) 2025 Frontman AI
# Licensed under the AGPL-3.0 — see LICENSE for details.

defmodule FrontmanServerWeb.CustomProvidersController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Providers

  def index(conn, _params) do
    json(conn, %{data: Providers.list_custom_providers(conn.assigns.current_scope)})
  end

  def create(conn, params) do
    attrs = Map.take(params, ["name", "base_url", "api_key", "models"])

    case Providers.create_custom_provider(conn.assigns.current_scope, attrs) do
      {:ok, provider} -> conn |> put_status(:created) |> json(%{data: provider})
      {:error, errors} -> validation_error(conn, errors)
    end
  end

  def update(conn, %{"provider_id" => provider_id} = params) do
    attrs =
      Map.take(params, ["name", "base_url", "models", "lock_version", "api_key_change"])

    case Providers.update_custom_provider(conn.assigns.current_scope, provider_id, attrs) do
      {:ok, provider} -> json(conn, %{data: provider})
      {:error, :not_found} -> not_found(conn)
      {:error, {:stale, provider}} -> stale(conn, provider)
      {:error, errors} -> validation_error(conn, errors)
    end
  end

  def delete(conn, %{"provider_id" => provider_id} = params) do
    case Providers.delete_custom_provider(
           conn.assigns.current_scope,
           provider_id,
           params["lock_version"]
         ) do
      :ok -> send_resp(conn, :no_content, "")
      {:error, :not_found} -> not_found(conn)
      {:error, {:stale, provider}} -> stale(conn, provider)
      {:error, errors} -> validation_error(conn, errors)
    end
  end

  defp not_found(conn) do
    conn |> put_status(:not_found) |> json(%{status: "error", code: "not_found"})
  end

  defp stale(conn, provider) do
    conn
    |> put_status(:conflict)
    |> json(%{status: "error", code: "stale", current_provider: provider})
  end

  defp validation_error(conn, errors) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{status: "error", code: "validation_failed", errors: errors})
  end
end
