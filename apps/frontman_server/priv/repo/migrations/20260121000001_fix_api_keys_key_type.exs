defmodule FrontmanServer.Repo.Migrations.FixApiKeysKeyType do
  use Ecto.Migration

  def up do
    # Change key column from varchar to bytea for proper binary storage
    # The encrypted data is binary and needs bytea type
    # First drop existing data since it can't be converted
    execute("DELETE FROM api_keys")
    execute("ALTER TABLE api_keys ALTER COLUMN key TYPE bytea USING key::bytea")
  end

  def down do
    execute("DELETE FROM api_keys")
    execute("ALTER TABLE api_keys ALTER COLUMN key TYPE varchar(255)")
  end
end
