# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.CustomLlmModel do
  @moduledoc """
  A model exposed by a user-defined custom LLM endpoint.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Providers.CustomLlmEndpoint

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "custom_llm_models" do
    field(:model_id, :string)
    field(:display_name, :string)
    field(:position, :integer)

    belongs_to(:endpoint, CustomLlmEndpoint)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for adding a model to an endpoint.
  """
  def changeset(model, attrs) do
    model
    |> cast(attrs, [:model_id, :display_name, :position])
    |> validate_required([:model_id])
    |> validate_length(:model_id, min: 1, max: 256)
  end

  @doc """
  Query helpers.
  """
  def for_endpoint(query \\ __MODULE__, endpoint_id) do
    from(m in query, where: m.endpoint_id == ^endpoint_id)
  end

  def with_model_id(query \\ __MODULE__, model_id) do
    from(m in query, where: m.model_id == ^model_id)
  end

  def ordered(query \\ __MODULE__) do
    from(m in query, order_by: [asc: m.position, asc: m.model_id])
  end
end
