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

    belongs_to(:user, User)

    has_many(:models, FrontmanServer.Providers.CustomProviderModel,
      foreign_key: :custom_provider_id,
      on_delete: :delete_all
    )

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a provider.
  Does not accept user_id - it must be set explicitly via the struct to prevent
  unauthorized user_id injection from untrusted input.
  """
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [:name, :base_url, :api_key])
    |> validate_required([:name, :base_url])
    |> validate_length(:name, min: 1, max: 64)
    |> validate_length(:base_url, min: 1, max: 512)
    |> validate_change(:base_url, fn :base_url, url ->
      case PublicURL.validate(url) do
        :ok -> []
        {:error, message} -> [base_url: message]
      end
    end)
    |> unique_constraint([:user_id, :name])
  end

  @doc """
  Query helpers.
  """
  def for_user(query \\ __MODULE__, user_id) do
    from(e in query, where: e.user_id == ^user_id)
  end
end
