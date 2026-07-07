defmodule FrontmanServer.Billing.Subscription do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Billing.Customer

  @intervals [:monthly, :yearly]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @type t :: %__MODULE__{}

  schema "billing_subscriptions" do
    field :stripe_subscription_id, :string
    field :stripe_customer_id, :string
    field :status, :string
    field :interval, Ecto.Enum, values: @intervals
    field :price_id, :string
    field :current_period_end, :utc_datetime
    field :trial_end, :utc_datetime
    field :cancel_at, :utc_datetime
    field :canceled_at, :utc_datetime

    belongs_to :billing_customer, Customer

    timestamps(type: :utc_datetime)
  end

  def for_user(query \\ __MODULE__, user_id) do
    from s in query,
      join: c in Customer,
      on: c.id == s.billing_customer_id,
      where: c.user_id == ^user_id
  end

  def with_consumed_trial(query \\ __MODULE__) do
    from s in query,
      where: s.status == "trialing" or not is_nil(s.trial_end)
  end

  def allow_access?(%__MODULE__{status: status})
      when status in ["trialing", "active", "past_due"],
      do: true

  def allow_access?(nil), do: false
  def allow_access?(%__MODULE__{}), do: false

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :stripe_subscription_id,
      :stripe_customer_id,
      :status,
      :interval,
      :price_id,
      :current_period_end,
      :trial_end,
      :cancel_at,
      :canceled_at
    ])
    |> validate_required([:billing_customer_id, :stripe_subscription_id, :status])
    |> unique_constraint(:billing_customer_id)
    |> unique_constraint(:stripe_subscription_id)
    |> foreign_key_constraint(:billing_customer_id)
  end
end
