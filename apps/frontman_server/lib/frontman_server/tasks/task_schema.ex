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
  alias FrontmanServer.Projects.Project
  alias FrontmanServer.Sandboxes.Sandbox
  alias FrontmanServer.Tasks.InteractionSchema

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "tasks" do
    field(:short_desc, :string)
    field(:branch, :string)

    belongs_to(:user, User)
    belongs_to(:project, Project)
    has_many(:interactions, InteractionSchema, foreign_key: :task_id)
    has_many(:sandboxes, Sandbox, foreign_key: :task_id)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new task.

  System fields (id, user_id) are set explicitly — never cast from user input.
  """
  @spec create_changeset(String.t(), Ecto.UUID.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(id, user_id, attrs) do
    %__MODULE__{id: id, user_id: user_id}
    |> cast(attrs, [:short_desc, :branch])
    |> validate_required([:id, :short_desc, :user_id])
    |> unique_constraint(:id, name: :tasks_pkey)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:project_id)
  end

  @doc """
  Changeset for updating a task's short description.
  """
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(task, attrs) do
    task
    |> cast(attrs, [:short_desc])
    |> validate_required([:short_desc])
  end

  # Query helpers

  @type t :: %__MODULE__{}

  @spec by_id(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def by_id(query \\ __MODULE__, id) do
    from(t in query, where: t.id == ^id)
  end

  @spec for_user(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def for_user(query \\ __MODULE__, user_id) do
    from(t in query, where: t.user_id == ^user_id)
  end

  @spec with_interactions(Ecto.Queryable.t()) :: Ecto.Query.t()
  def with_interactions(query \\ __MODULE__) do
    from(t in query, preload: [:interactions])
  end

  @spec ordered_by_updated(Ecto.Queryable.t()) :: Ecto.Query.t()
  def ordered_by_updated(query \\ __MODULE__) do
    from(t in query, order_by: [desc: t.updated_at])
  end

  @spec limited(Ecto.Queryable.t(), non_neg_integer()) :: Ecto.Query.t()
  def limited(query \\ __MODULE__, count) do
    from(t in query, limit: ^count)
  end
end
