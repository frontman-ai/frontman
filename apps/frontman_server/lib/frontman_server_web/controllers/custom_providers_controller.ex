# Frontman Server
# Copyright (C) 2025 Frontman AI
# Licensed under the AGPL-3.0 — see LICENSE for details.

defmodule FrontmanServerWeb.CustomProvidersController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Providers

  def index(conn, _params) do
    scope = conn.assigns.current_scope
    json(conn, %{providers: Providers.list_custom_providers(scope)})
  end

  def create(conn, params) do
    scope = conn.assigns.current_scope
    attrs = Map.take(params, ["name", "base_url", "api_key"])

    case Providers.create_custom_provider(scope, attrs) do
      {:ok, provider} ->
        json(conn, %{provider: provider})

      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: errors})
    end
  end

  def update(conn, %{"provider_id" => provider_id} = params) do
    scope = conn.assigns.current_scope
    attrs = Map.take(params, ["name", "base_url", "api_key"])

    case Providers.update_custom_provider(scope, provider_id, attrs) do
      {:ok, provider} ->
        json(conn, %{provider: provider})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{status: "error", error: "not_found"})

      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: errors})
    end
  end

  def delete(conn, %{"provider_id" => provider_id}) do
    scope = conn.assigns.current_scope

    case Providers.delete_custom_provider(scope, provider_id) do
      :ok ->
        json(conn, %{status: "ok"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{status: "error", error: "not_found"})
    end
  end

  def add_model(conn, %{"provider_id" => provider_id} = params) do
    scope = conn.assigns.current_scope
    attrs = Map.take(params, ["model_id"])

    case Providers.add_custom_provider_model(scope, provider_id, attrs) do
      {:ok, provider} ->
        json(conn, %{provider: provider})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{status: "error", error: "not_found"})

      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: errors})
    end
  end

  def remove_model(conn, %{
        "provider_id" => provider_id,
        "provider_model_id" => provider_model_id
      }) do
    scope = conn.assigns.current_scope

    case Providers.remove_custom_provider_model(scope, provider_id, provider_model_id) do
      {:ok, provider} ->
        json(conn, %{provider: provider})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{status: "error", error: "not_found"})
    end
  end
end
