defmodule FrontmanServer.Repo.Migrations.CreateWordpressConnections do
  use Ecto.Migration

  def change do
    create table(:wordpress_connections, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:catalog_url, :text, null: false)
      add(:call_url, :text, null: false)
      add(:username, :string, null: false)
      add(:password, :binary, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:wordpress_connections, [:user_id]))
  end
end
