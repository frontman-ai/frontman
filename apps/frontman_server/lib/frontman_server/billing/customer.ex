defmodule FrontmanServer.Billing.Customer do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Billing.Subscription

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @type t :: %__MODULE__{}

  schema "billing_customers" do
    field :stripe_customer_id, :string
    field :stripe_customer_account_id, :string

    belongs_to :user, User
    has_one :subscription, Subscription, foreign_key: :billing_customer_id

    timestamps(type: :utc_datetime)
  end

  def for_user(query \\ __MODULE__, user_id) do
    from c in query, where: c.user_id == ^user_id
  end

  @doc false
  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [:stripe_customer_id, :stripe_customer_account_id])
    |> validate_required([:user_id])
    |> validate_customer_reference()
    |> unique_constraint(:user_id)
    |> unique_constraint(:stripe_customer_id)
    |> unique_constraint(:stripe_customer_account_id)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_customer_reference(changeset) do
    if get_field(changeset, :stripe_customer_id) ||
         get_field(changeset, :stripe_customer_account_id) do
      changeset
    else
      add_error(changeset, :stripe_customer_id, "or stripe_customer_account_id must be present")
    end
  end
end
