defmodule FrontmanServer.Repo.Migrations.FixApiKeysKeyType do
  use Ecto.Migration

  def up do
    execute("DELETE FROM api_keys")
    execute("ALTER TABLE api_keys ALTER COLUMN key TYPE bytea USING key::bytea")
  end

  def down do
    execute("DELETE FROM api_keys")
    execute("ALTER TABLE api_keys ALTER COLUMN key TYPE varchar(255)")
  end
end
