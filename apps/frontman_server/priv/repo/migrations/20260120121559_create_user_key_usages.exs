defmodule FrontmanServer.Repo.Migrations.CreateUserKeyUsages do
  use Ecto.Migration

  def change do
    create table(:user_key_usages, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:count, :integer, null: false, default: 0)
      add(:limit, :integer, null: false, default: 10)
      add(:provider, :string)
      add(:last_used_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:user_key_usages, [:user_id]))
  end
end
