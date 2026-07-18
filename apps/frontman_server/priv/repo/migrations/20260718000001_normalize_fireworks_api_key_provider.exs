defmodule FrontmanServer.Repo.Migrations.NormalizeFireworksApiKeyProvider do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION normalize_api_key_provider() RETURNS trigger AS $$
    BEGIN
      IF NEW.provider = 'fireworks' THEN
        NEW.provider := 'fireworks_ai';
      END IF;

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER api_keys_normalize_provider
    BEFORE INSERT OR UPDATE OF provider ON api_keys
    FOR EACH ROW EXECUTE FUNCTION normalize_api_key_provider()
    """)

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
    execute("DROP TRIGGER IF EXISTS api_keys_normalize_provider ON api_keys")
    execute("DROP FUNCTION IF EXISTS normalize_api_key_provider()")
    execute("UPDATE api_keys SET provider = 'fireworks' WHERE provider = 'fireworks_ai'")
  end
end
