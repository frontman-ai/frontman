defmodule FrontmanServer.Repo.Migrations.CreateBillingCustomers do
  use Ecto.Migration

  def change do
    create table(:billing_customers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :stripe_customer_id, :string
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:billing_customers, [:user_id])

    create unique_index(:billing_customers, [:stripe_customer_id],
             where: "stripe_customer_id IS NOT NULL"
           )
  end
end
