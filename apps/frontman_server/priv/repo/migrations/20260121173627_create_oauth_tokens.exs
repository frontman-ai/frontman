defmodule FrontmanServer.Repo.Migrations.CreateOauthTokens do
  use Ecto.Migration

  def change do
    create table(:oauth_tokens, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:provider, :string, null: false)
      add(:access_token, :binary, null: false)
      add(:refresh_token, :binary, null: false)
      add(:expires_at, :utc_datetime, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:oauth_tokens, [:user_id, :provider]))
    create(index(:oauth_tokens, [:user_id]))
  end
end
