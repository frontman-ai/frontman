defmodule FrontmanServer.Repo.Migrations.AddEmbeddedClientFieldsToUsersTokens do
  use Ecto.Migration

  def change do
    alter table(:users_tokens) do
      add :approved_origin, :string
      add :expires_at, :utc_datetime
      add :last_used_at, :utc_datetime
    end
  end
end
