# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Accounts.UserIdentity do
  @moduledoc """
  Schema for OAuth provider identities linked to user accounts.

  Supports multiple OAuth providers (GitHub, Google) per user, enabling
  social login while maintaining the existing email/password authentication.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @providers ~w(github google)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_identities" do
    field :provider, :string
    field :provider_id, :string
    field :provider_email, :string
    field :provider_name, :string
    field :provider_avatar_url, :string
    field :last_signed_in_at, :utc_datetime

    belongs_to :user, FrontmanServer.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new user identity.
  """
  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [
      :provider,
      :provider_id,
      :provider_email,
      :provider_name,
      :provider_avatar_url,
      :user_id
    ])
    |> validate_required([:provider, :provider_id, :user_id])
    |> validate_inclusion(:provider, @providers)
    |> unique_constraint([:user_id, :provider],
      message: "you have already connected this provider"
    )
    |> unique_constraint([:provider, :provider_id],
      message: "this account is already linked to another user"
    )
  end

  @doc """
  Updates the last_signed_in_at timestamp.
  """
  def touch_changeset(identity) do
    change(identity, last_signed_in_at: DateTime.utc_now(:second))
  end
end
