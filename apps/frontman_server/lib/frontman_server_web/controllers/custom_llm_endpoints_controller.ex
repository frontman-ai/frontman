# Frontman Server
# Copyright (C) 2025 Frontman AI
# Licensed under the AGPL-3.0 — see LICENSE for details.

defmodule FrontmanServerWeb.CustomLlmEndpointsController do
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.CustomLlmEndpoints
  alias FrontmanServer.Providers.CustomLlmEndpoint

  def index(conn, _params) do
    scope = conn.assigns.current_scope
    endpoints = CustomLlmEndpoints.list_endpoints(scope)
    json(conn, %{endpoints: Enum.map(endpoints, &serialize_endpoint/1)})
  end

  def create(conn, params) do
    scope = conn.assigns.current_scope
    attrs = Map.take(params, ["name", "base_url", "api_key"])

    case CustomLlmEndpoints.create_endpoint(scope, attrs) do
      {:ok, endpoint} ->
        Providers.broadcast_config_changed(scope.user.id)
        json(conn, %{endpoint: serialize_endpoint(endpoint)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: translate_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    scope = conn.assigns.current_scope
    attrs = Map.take(params, ["name", "base_url", "api_key"])

    case CustomLlmEndpoints.update_endpoint(scope, id, attrs) do
      {:ok, endpoint} ->
        Providers.broadcast_config_changed(scope.user.id)
        json(conn, %{endpoint: serialize_endpoint(endpoint)})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{status: "error", error: "not_found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: translate_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    case CustomLlmEndpoints.delete_endpoint(scope, id) do
      :ok ->
        Providers.broadcast_config_changed(scope.user.id)
        json(conn, %{status: "ok"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{status: "error", error: "not_found"})
    end
  end

  def add_model(conn, %{"id" => endpoint_id} = params) do
    scope = conn.assigns.current_scope
    attrs = Map.take(params, ["model_id", "display_name", "position"])

    case CustomLlmEndpoints.add_model(scope, endpoint_id, attrs) do
      {:ok, model} ->
        Providers.broadcast_config_changed(scope.user.id)
        json(conn, %{model: serialize_model(model)})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{status: "error", error: "not_found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{status: "error", errors: translate_errors(changeset)})
    end
  end

  def remove_model(conn, %{"id" => endpoint_id, "model_id" => model_id}) do
    scope = conn.assigns.current_scope

    case CustomLlmEndpoints.remove_model(scope, endpoint_id, model_id) do
      :ok ->
        Providers.broadcast_config_changed(scope.user.id)
        json(conn, %{status: "ok"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{status: "error", error: "not_found"})
    end
  end

  defp serialize_endpoint(%CustomLlmEndpoint{} = endpoint) do
    %{
      id: endpoint.id,
      name: endpoint.name,
      base_url: endpoint.base_url,
      has_api_key: not is_nil(endpoint.api_key),
      models: Enum.map(endpoint.models || [], &serialize_model/1)
    }
  end

  defp serialize_model(model) do
    %{
      id: model.id,
      model_id: model.model_id,
      display_name: model.display_name,
      position: model.position
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
