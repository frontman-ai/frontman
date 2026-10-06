defmodule FrontmanServer.Repo.Migrations.CreateBillingRunAllowances do
  use Ecto.Migration

  def change do
    create table(:billing_run_allowances, primary_key: false) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :used, :integer, null: false
    end

    create constraint(:billing_run_allowances, :valid_run_allowance,
             check: "used BETWEEN 1 AND 5"
           )
  end
end
