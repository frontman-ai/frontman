defmodule FrontmanServer.Organizations.Membership do
  @moduledoc """
  Schema for organization memberships - the join between users and organizations with role.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Organizations.Organization

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memberships" do
    field :role, Ecto.Enum, values: [:owner, :member]

    belongs_to :user, User
    belongs_to :organization, Organization

    timestamps(type: :utc_datetime)
  end

  # Queries

  def for_organization(query \\ __MODULE__, organization_id) do
    from m in query, where: m.organization_id == ^organization_id
  end

  def for_user(query \\ __MODULE__, user_id) do
    from m in query, where: m.user_id == ^user_id
  end

  def with_role(query \\ __MODULE__, role) do
    from m in query, where: m.role == ^role
  end

  def with_user(query \\ __MODULE__) do
    from m in query, preload: [:user]
  end

  def with_organization(query \\ __MODULE__) do
    from m in query, preload: [:organization]
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :user_id, :organization_id])
    |> validate_required([:role, :user_id, :organization_id])
    |> unique_constraint([:user_id, :organization_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:organization_id)
  end
end
