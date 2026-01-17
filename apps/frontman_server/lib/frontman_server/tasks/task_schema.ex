defmodule FrontmanServer.Tasks.TaskSchema do
  @moduledoc """
  Ecto schema for persisted tasks.

  Tasks are client-provided (UUID comes from the client), so we disable autogenerate.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Tasks.InteractionSchema

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "tasks" do
    field :short_desc, :string
    field :framework, :string

    belongs_to :user, User
    has_many :interactions, InteractionSchema, foreign_key: :task_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a new task.
  """
  @spec create_changeset(map()) :: Ecto.Changeset.t()
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:id, :short_desc, :framework, :user_id])
    |> validate_required([:id, :short_desc, :framework, :user_id])
    |> foreign_key_constraint(:user_id)
  end

  # Query helpers

  @type t :: %__MODULE__{}

  @spec by_id(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def by_id(query \\ __MODULE__, id) do
    from t in query, where: t.id == ^id
  end

  @spec for_user(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def for_user(query \\ __MODULE__, user_id) do
    from t in query, where: t.user_id == ^user_id
  end

  @spec with_interactions(Ecto.Queryable.t()) :: Ecto.Query.t()
  def with_interactions(query \\ __MODULE__) do
    from t in query, preload: [:interactions]
  end

  @spec ordered_by_updated(Ecto.Queryable.t()) :: Ecto.Query.t()
  def ordered_by_updated(query \\ __MODULE__) do
    from t in query, order_by: [desc: t.updated_at]
  end
end
