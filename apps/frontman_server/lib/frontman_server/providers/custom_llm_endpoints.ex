# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.CustomLlmEndpoints do
  @moduledoc """
  CRUD for user-defined OpenAI-compatible LLM endpoints.

  Every function scopes access through the caller's `%Accounts.Scope{}`:
  a user can never read or mutate another user's endpoints.
  """

  use Boundary, deps: [FrontmanServer, FrontmanServer.Accounts, FrontmanServer.Providers]

  alias FrontmanServer.Repo

  alias FrontmanServer.Accounts.{Scope, User}

  alias FrontmanServer.Providers.{CustomLlmEndpoint, CustomLlmModel}

  @doc """
  Lists all endpoints owned by the current user, with models preloaded
  ordered by position then model_id.
  """
  def list_endpoints(%Scope{user: %User{}} = scope) do
    CustomLlmEndpoint
    |> CustomLlmEndpoint.for_user(scope.user.id)
    |> Repo.all()
    |> Repo.preload(models: ordered_models())
  end

  @doc """
  Gets a single endpoint owned by the current user.

  Raises `Ecto.NoResultsError` if the endpoint does not exist or belongs
  to another user.
  """
  def get_endpoint!(%Scope{user: %User{}} = scope, id) do
    CustomLlmEndpoint
    |> CustomLlmEndpoint.for_user(scope.user.id)
    |> Repo.get!(id)
  end

  @doc """
  Creates an endpoint for the current user.

  ## Examples

      iex> create_endpoint(scope, %{name: "vllm", base_url: "http://localhost:8000/v1"})
      {:ok, %CustomLlmEndpoint{}}

      iex> create_endpoint(scope, %{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_endpoint(%Scope{user: %User{id: user_id}}, attrs) do
    %CustomLlmEndpoint{user_id: user_id}
    |> CustomLlmEndpoint.changeset(attrs)
    |> Repo.insert()
    |> preload_models()
  end

  @doc """
  Updates an endpoint owned by the current user.

  An absent `:api_key` in attrs leaves the existing key untouched.
  """
  def update_endpoint(%Scope{user: %User{}} = scope, id, attrs) do
    case fetch_owned_endpoint(scope, id) do
      %CustomLlmEndpoint{} = endpoint ->
        endpoint
        |> CustomLlmEndpoint.changeset(attrs)
        |> Repo.update()
        |> preload_models()

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Deletes an endpoint owned by the current user along with its models.
  """
  def delete_endpoint(%Scope{user: %User{}} = scope, id) do
    case fetch_owned_endpoint(scope, id) do
      %CustomLlmEndpoint{} = endpoint ->
        Repo.delete!(endpoint)
        :ok

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Adds a model to an endpoint owned by the current user.
  """
  def add_model(%Scope{user: %User{}} = scope, endpoint_id, attrs) do
    case fetch_owned_endpoint(scope, endpoint_id) do
      %CustomLlmEndpoint{} ->
        %CustomLlmModel{endpoint_id: endpoint_id}
        |> CustomLlmModel.changeset(attrs)
        |> Repo.insert()

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Removes a single model (by its model_id string) from an endpoint owned
  by the current user.
  """
  def remove_model(%Scope{user: %User{}} = scope, endpoint_id, model_id) do
    case fetch_owned_endpoint(scope, endpoint_id) do
      %CustomLlmEndpoint{} ->
        CustomLlmModel
        |> CustomLlmModel.for_endpoint(endpoint_id)
        |> CustomLlmModel.with_model_id(model_id)
        |> Repo.delete_all()
        |> case do
          {1, _} -> :ok
          {0, _} -> {:error, :not_found}
        end

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets a single endpoint owned by the current user without raising.

  Returns `{:ok, endpoint}` with models preloaded (ordered by position
  then model_id), or `:error` when the endpoint does not exist or belongs
  to another user.
  """
  def get_endpoint_safe(%Scope{user: %User{id: user_id}}, id) do
    CustomLlmEndpoint
    |> CustomLlmEndpoint.for_user(user_id)
    |> Repo.get(id)
    |> Repo.preload(models: ordered_models())
    |> case do
      %CustomLlmEndpoint{} = endpoint -> {:ok, endpoint}
      nil -> :error
    end
  end

  defp fetch_owned_endpoint(%Scope{user: %User{id: user_id}}, id) do
    CustomLlmEndpoint
    |> CustomLlmEndpoint.for_user(user_id)
    |> Repo.get(id)
  end

  defp preload_models({:ok, %CustomLlmEndpoint{} = endpoint}) do
    {:ok, Repo.preload(endpoint, models: ordered_models())}
  end

  defp preload_models(other), do: other

  defp ordered_models do
    CustomLlmModel.ordered()
  end
end
