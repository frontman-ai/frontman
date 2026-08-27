# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.CustomProviderModel do
  @moduledoc """
  A model exposed by a user-defined custom provider.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Providers.CustomProvider

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "custom_provider_models" do
    field(:model_id, :string)

    belongs_to(:custom_provider, CustomProvider)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for adding a model to a provider.
  """
  def changeset(%__MODULE__{} = model, attrs) do
    model
    |> cast(attrs, [:model_id])
    |> validate_required([:model_id])
    |> validate_length(:model_id, min: 1, max: 256)
    |> unique_constraint([:custom_provider_id, :model_id], error_key: :model_id)
  end

  def ordered(query \\ __MODULE__) do
    from(m in query, order_by: [asc: m.model_id])
  end
end
