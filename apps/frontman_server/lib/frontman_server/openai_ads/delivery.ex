defmodule FrontmanServer.OpenAIAds.Delivery do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Query
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "openai_ads_deliveries" do
    field :user_id, :binary_id
    field :consent_id, :binary_id
    field :kind, :string
    field :source_ref, :string
    field :timestamp_ms, :integer
    field :oppref, :string, redact: true
    field :status, :string
  end

  def pending_for_consent(id),
    do: from(d in __MODULE__, where: d.consent_id == ^id and d.status == "pending")
end
