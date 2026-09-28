# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.CustomProvider do
  @moduledoc """
  A user-defined OpenAI-compatible LLM provider.
  The optional API key is encrypted at rest using FrontmanServer.Vault.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.PublicURL

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "custom_providers" do
    field(:name, :string)
    field(:base_url, :string)
    field(:api_key, FrontmanServer.Encrypted.Binary)
    field(:models, {:array, :string}, default: [])
    field(:lock_version, :integer, default: 1)

    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a provider.
  Does not accept user_id - it must be set explicitly via the struct to prevent
  unauthorized user_id injection from untrusted input.
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = provider, attrs) do
    provider
    |> cast(attrs, [:name, :base_url, :api_key, :models], empty_values: [])
    |> validate_required([:name, :base_url, :models])
    |> validate_length(:name, min: 1, max: 64)
    |> validate_length(:base_url, min: 1, max: 512)
    |> validate_change(:base_url, fn :base_url, url ->
      case PublicURL.validate(url) do
        :ok -> []
        {:error, message} -> [base_url: message]
      end
    end)
    |> update_change(:models, fn
      nil -> nil
      models -> models |> Enum.map(&String.trim/1) |> Enum.sort()
    end)
    |> validate_change(:models, &validate_models/2)
    |> unique_constraint([:user_id, :name], error_key: :name)
    |> check_constraint(:models, name: :custom_providers_models_count)
  end

  defp validate_models(:models, models) do
    cond do
      length(models) > 100 ->
        [models: "must contain at most 100 model IDs"]

      Enum.any?(models, &(&1 == "")) ->
        [models: "must not contain empty model IDs"]

      Enum.any?(models, &(String.length(&1) > 256)) ->
        [models: "model IDs must be at most 256 characters"]

      length(Enum.uniq(models)) != length(models) ->
        [models: "must contain unique model IDs"]

      true ->
        []
    end
  end

  @doc """
  Query helpers.
  """
  def for_user(query \\ __MODULE__, user_id) do
    from(e in query, where: e.user_id == ^user_id)
  end
end
