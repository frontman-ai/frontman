defmodule FrontmanServer.Providers.OAuthToken do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "oauth_tokens" do
    field(:provider, :string)
    field(:access_token, FrontmanServer.Encrypted.Binary)
    field(:refresh_token, FrontmanServer.Encrypted.Binary)
    field(:expires_at, :utc_datetime)
    field(:metadata, :map, default: %{})

    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  def changeset(oauth_token, attrs) do
    oauth_token
    |> cast(attrs, [:provider, :access_token, :refresh_token, :expires_at, :metadata])
    |> validate_required([:provider, :access_token, :refresh_token, :expires_at])
    |> validate_length(:provider, min: 1, max: 64)
    |> validate_length(:access_token, min: 1)
    |> validate_length(:refresh_token, min: 1)
    |> unique_constraint([:user_id, :provider], name: :oauth_tokens_user_id_provider_index)
  end

  def for_user(query \\ __MODULE__, user_id) do
    from(t in query, where: t.user_id == ^user_id)
  end

  def for_user_and_provider(query \\ __MODULE__, user_id, provider) do
    from(t in query, where: t.user_id == ^user_id and t.provider == ^provider)
  end

  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  def calculate_expires_at(expires_in) when is_integer(expires_in) do
    DateTime.utc_now()
    |> DateTime.add(expires_in, :second)
    |> DateTime.truncate(:second)
  end
end
