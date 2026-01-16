defmodule FrontmanServer.Repo.Migrations.CreateMemberships do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE membership_role AS ENUM ('owner', 'member')", "DROP TYPE membership_role"

    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :membership_role, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:memberships, [:user_id])
    create index(:memberships, [:organization_id])
    create unique_index(:memberships, [:user_id, :organization_id])
  end
end
