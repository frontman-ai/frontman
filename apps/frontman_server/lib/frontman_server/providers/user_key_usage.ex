defmodule FrontmanServer.Providers.UserKeyUsage do
  @moduledoc """
  Tracks lifetime usage of server-provided API keys per user.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias FrontmanServer.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_key_usages" do
    field(:count, :integer, default: 0)
    field(:provider, :string)
    field(:last_used_at, :utc_datetime)

    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a usage record.
  Does not accept user_id - it must be set explicitly via the struct to prevent
  unauthorized user_id injection from untrusted input.
  """
  def changeset(usage, attrs) do
    usage
    |> cast(attrs, [:count, :provider, :last_used_at])
    |> validate_required([:count])
    |> validate_number(:count, greater_than_or_equal_to: 0)
    |> unique_constraint([:user_id, :provider], name: :user_key_usages_user_id_provider_index)
  end

  @doc """
  Changeset for incrementing usage count.
  """
  def increment_changeset(usage) do
    usage
    |> change(count: usage.count + 1, last_used_at: DateTime.utc_now(:second))
  end
end
