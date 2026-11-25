defmodule FrontmanServer.OpenAIAds.Consent do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "openai_ads_consents" do
    field :user_id, :binary_id
    field :oppref, :string, redact: true
    field :granted_at, :utc_datetime_usec
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
  end

  def for_user(id), do: where(__MODULE__, user_id: ^id)

  def latest_for_user(id),
    do:
      from(c in for_user(id),
        where: is_nil(c.revoked_at),
        order_by: [desc: c.granted_at],
        limit: 1
      )

  def lock_query(id), do: from(c in __MODULE__, where: c.id == ^id, lock: "FOR UPDATE")

  def user_lock(id),
    do: from(u in "users", where: u.id == type(^id, :binary_id), select: u.id, lock: "FOR UPDATE")
end
