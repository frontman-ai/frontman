defmodule FrontmanServer.Repo.Migrations.CreateBillingSubscriptions do
  use Ecto.Migration

  def change do
    create table(:billing_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :stripe_subscription_id, :string, null: false
      add :stripe_customer_id, :string
      add :stripe_customer_account_id, :string
      add :status, :string, null: false
      add :interval, :string
      add :price_id, :string
      add :current_period_end, :utc_datetime
      add :trial_end, :utc_datetime
      add :cancel_at, :utc_datetime
      add :canceled_at, :utc_datetime

      add :billing_customer_id,
          references(:billing_customers, on_delete: :delete_all, type: :binary_id),
          null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:billing_subscriptions, [:billing_customer_id])
    create index(:billing_subscriptions, [:status])
    create index(:billing_subscriptions, [:stripe_customer_id])
    create index(:billing_subscriptions, [:stripe_customer_account_id])
    create unique_index(:billing_subscriptions, [:stripe_subscription_id])
  end
end
