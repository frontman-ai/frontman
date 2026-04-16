defmodule FrontmanServer.Repo.Migrations.AllowNullableRefreshAndExpires do
  use Ecto.Migration

  def change do
    alter table(:oauth_tokens) do
      modify :refresh_token, :binary, null: true, from: {:binary, null: false}
      modify :expires_at, :utc_datetime, null: true, from: {:utc_datetime, null: false}
    end
  end
end
