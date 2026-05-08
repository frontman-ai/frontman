defmodule FrontmanServer.Billing.StripeEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "stripe_events" do
    field :stripe_event_id, :string
    field :type, :string
    field :processed_at, :utc_datetime
    field :payload, :map

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(stripe_event, attrs) do
    stripe_event
    |> cast(attrs, [:stripe_event_id, :type, :processed_at, :payload])
    |> validate_required([:stripe_event_id, :type, :processed_at])
    |> unique_constraint(:stripe_event_id)
  end
end
