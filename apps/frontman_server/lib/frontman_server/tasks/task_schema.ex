# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.TaskSchema do
  @moduledoc """
  Ecto schema for persisted tasks.

  Tasks are client-provided (UUID comes from the client), so we disable autogenerate.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Frameworks
  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks.InteractionSchema

  @framework_values Frameworks.ids()
  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "tasks" do
    field(:short_desc, :string)
    field(:framework, Ecto.Enum, values: @framework_values)
    field(:current_model, :string)
    belongs_to(:user, User)
    has_many(:interaction_rows, InteractionSchema, foreign_key: :task_id)

    timestamps(type: :utc_datetime)
  end

  @doc "Returns the default short description for a new task."
  def default_title do
    "New Task"
  end

  @doc """
  Changeset for creating a new task.
  """
  def create_changeset(attrs, catalog) do
    %__MODULE__{}
    |> cast(attrs, [:id, :short_desc, :framework, :user_id, :current_model])
    |> validate_required([:id, :short_desc, :framework, :user_id, :current_model])
    |> validate_current_model(catalog)
    |> unique_constraint(:id, name: :tasks_pkey)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for updating a task's short description.
  """
  def update_changeset(task, attrs) do
    task
    |> cast(attrs, [:short_desc])
    |> validate_required([:short_desc])
  end

  @doc "Changeset for selecting an available conversation model."
  def model_changeset(task, attrs, catalog) do
    task
    |> cast(attrs, [:current_model])
    |> validate_required([:current_model])
    |> validate_current_model(catalog)
  end

  defp validate_current_model(%Ecto.Changeset{valid?: false} = changeset, _catalog),
    do: changeset

  defp validate_current_model(changeset, catalog) do
    case Providers.model_available?(catalog, get_field(changeset, :current_model)) do
      true -> changeset
      false -> add_error(changeset, :current_model, "is unavailable; select another model")
    end
  end

  def by_id(query \\ __MODULE__, id) do
    from(t in query, where: t.id == ^id)
  end

  def for_user(query \\ __MODULE__, user_id) do
    from(t in query, where: t.user_id == ^user_id)
  end

  def by_id_for_user(id, user_id) do
    __MODULE__
    |> by_id(id)
    |> for_user(user_id)
  end

  def locked_for_update(query \\ __MODULE__) do
    from(t in query, lock: "FOR UPDATE")
  end

  def ordered_by_updated(query \\ __MODULE__) do
    from(t in query, order_by: [desc: t.updated_at])
  end

  def limited(query \\ __MODULE__, count) do
    from(t in query, limit: ^count)
  end
end
