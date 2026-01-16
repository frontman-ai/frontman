defmodule FrontmanServer.Organizations.Organization do
  @moduledoc """
  Schema for organizations - workspaces that group users together.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Organizations.Membership

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "organizations" do
    field :name, :string
    field :slug, :string

    has_many :memberships, Membership
    has_many :users, through: [:memberships, :user]

    timestamps(type: :utc_datetime)
  end

  # Queries

  def for_user(query \\ __MODULE__, user_id) do
    from o in query,
      join: m in Membership,
      on: m.organization_id == o.id,
      where: m.user_id == ^user_id
  end

  def by_slug(query \\ __MODULE__, slug) do
    from o in query, where: o.slug == ^slug
  end

  def ordered_by_name(query \\ __MODULE__) do
    from o in query, order_by: [asc: o.name]
  end

  @doc false
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name])
    |> maybe_generate_slug()
    |> validate_required([:slug])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must contain only lowercase letters, numbers, and hyphens"
    )
    |> unique_constraint(:slug)
  end

  defp maybe_generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        case get_change(changeset, :name) do
          nil -> changeset
          name -> put_change(changeset, :slug, slugify(name))
        end

      _ ->
        changeset
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
