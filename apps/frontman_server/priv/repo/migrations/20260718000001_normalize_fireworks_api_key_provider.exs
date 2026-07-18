defmodule FrontmanServer.Repo.Migrations.NormalizeFireworksApiKeyProvider do
  use Ecto.Migration

  def up do
    execute("""
    DELETE FROM api_keys legacy
    USING api_keys canonical
    WHERE legacy.provider = 'fireworks'
      AND canonical.provider = 'fireworks_ai'
      AND legacy.user_id = canonical.user_id
    """)

    execute("UPDATE api_keys SET provider = 'fireworks_ai' WHERE provider = 'fireworks'")
  end

  def down do
    execute("UPDATE api_keys SET provider = 'fireworks' WHERE provider = 'fireworks_ai'")
  end
end
