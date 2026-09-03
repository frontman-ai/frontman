# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Skills.Skill do
  @moduledoc "Schema for globally usable Frontman skills."

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @name_format ~r/^[a-z0-9][a-z0-9_-]*$/

  schema "skills" do
    field :name, :string
    field :description, :string
    field :content, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(skill, attrs) do
    skill
    |> cast(attrs, [:name, :description, :content])
    |> update_change(:name, &String.downcase/1)
    |> validate_required([:name, :description, :content])
    |> validate_format(:name, @name_format)
    |> validate_length(:description, min: 1, max: 200)
    |> validate_length(:content, min: 1)
    |> unique_constraint(:name)
    |> check_constraint(:name, name: :skills_name_format)
  end

  def ordered_by_name(query \\ __MODULE__) do
    from(s in query, order_by: [asc: s.name])
  end
end
