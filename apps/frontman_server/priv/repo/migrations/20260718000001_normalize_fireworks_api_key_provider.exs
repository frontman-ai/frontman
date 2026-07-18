defmodule FrontmanServer.Repo.Migrations.NormalizeFireworksApiKeyProvider do
  use Ecto.Migration

  def up do
    execute("UPDATE api_keys SET provider = 'fireworks_ai' WHERE provider = 'fireworks'")
  end

  def down do
    raise Ecto.MigrationError,
          "irreversible migration: canonical Fireworks credentials cannot be distinguished from migrated rows"
  end
end
