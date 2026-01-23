defmodule FrontmanServer.Providers.ApiKey do
  @moduledoc """
  Stores user API keys by provider.
  Keys are encrypted at rest using FrontmanServer.Vault.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "api_keys" do
    field(:provider, :string)
    field(:key, FrontmanServer.Encrypted.Binary)

    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for storing an API key.
  Does not accept user_id - it must be set explicitly via the struct to prevent
  unauthorized user_id injection from untrusted input.
  """
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:provider, :key])
    |> validate_required([:provider, :key])
    |> validate_length(:provider, min: 1, max: 64)
    |> validate_length(:key, min: 1)
    |> unique_constraint([:user_id, :provider], name: :api_keys_user_id_provider_index)
  end

  @doc """
  Query helpers.
  """
  def for_user(query \\ __MODULE__, user_id) do
    from(k in query, where: k.user_id == ^user_id)
  end

  def for_user_and_provider(query \\ __MODULE__, user_id, provider) do
    from(k in query, where: k.user_id == ^user_id and k.provider == ^provider)
  end
end
