defmodule FrontmanServer.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:provider, :string, null: false)
      add(:key, :binary, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:api_keys, [:user_id]))
    create(unique_index(:api_keys, [:user_id, :provider]))
  end
end
