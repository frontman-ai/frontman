defmodule FrontmanServer.Providers.OAuthToken do
  @moduledoc """
  Stores OAuth tokens for LLM providers (e.g., Anthropic Claude Pro/Max).
  Tokens are encrypted at rest using FrontmanServer.Vault.
  """

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

  @doc """
  Changeset for storing OAuth tokens.
  Does not accept user_id - it must be set explicitly via the struct to prevent
  unauthorized user_id injection from untrusted input.
  """
  def changeset(oauth_token, attrs) do
    oauth_token
    |> cast(attrs, [:provider, :access_token, :refresh_token, :expires_at, :metadata])
    |> validate_required([:provider, :access_token, :refresh_token, :expires_at])
    |> validate_length(:provider, min: 1, max: 64)
    |> unique_constraint([:user_id, :provider], name: :oauth_tokens_user_id_provider_index)
  end

  @doc """
  Query helpers.
  """
  def for_user(query \\ __MODULE__, user_id) do
    from(t in query, where: t.user_id == ^user_id)
  end

  def for_user_and_provider(query \\ __MODULE__, user_id, provider) do
    from(t in query, where: t.user_id == ^user_id and t.provider == ^provider)
  end

  @doc """
  Returns true if the token is expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :lt
  end

  @doc """
  Calculates the expiration DateTime from an `expires_in` value in seconds.
  """
  @spec calculate_expires_at(integer()) :: DateTime.t()
  def calculate_expires_at(expires_in) when is_integer(expires_in) do
    DateTime.utc_now()
    |> DateTime.add(expires_in, :second)
    |> DateTime.truncate(:second)
  end
end
