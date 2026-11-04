# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.WordPress.Connection do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "wordpress_connections" do
    field(:catalog_url, :string)
    field(:call_url, :string)
    field(:username, :string)
    field(:password, FrontmanServer.Encrypted.Binary, redact: true)
    belongs_to(:user, FrontmanServer.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def sites_for_user(user_id) do
    from connection in __MODULE__,
      where: connection.user_id == ^user_id,
      order_by: connection.id,
      select: %{id: connection.id, catalog_url: connection.catalog_url}
  end

  def owned(user_id) do
    from connection in __MODULE__, where: connection.user_id == ^user_id, order_by: connection.id
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [:catalog_url, :call_url, :username, :password])
    |> validate_required([:catalog_url, :call_url, :username, :password])
    |> validate_length(:catalog_url, max: 2048)
    |> validate_length(:call_url, max: 2048)
    |> validate_length(:username, max: 255)
  end
end
