defmodule FrontmanServer.Repo.Migrations.NormalizeOpenAIOAuthProvider do
  use Ecto.Migration

  def up do
    execute("""
    DELETE FROM oauth_tokens legacy
    USING oauth_tokens kept
    WHERE legacy.provider IN ('chatgpt', 'openai')
      AND kept.provider = 'openai_codex'
      AND legacy.user_id = kept.user_id
    """)

    execute("""
    DELETE FROM oauth_tokens legacy
    USING oauth_tokens kept
    WHERE legacy.provider = 'chatgpt'
      AND kept.provider = 'openai'
      AND legacy.user_id = kept.user_id
    """)

    execute(
      "UPDATE oauth_tokens SET provider = 'openai_codex' WHERE provider IN ('chatgpt', 'openai')"
    )
  end

  def down do
    execute("""
    DELETE FROM oauth_tokens kept
    USING oauth_tokens legacy
    WHERE kept.provider = 'openai_codex'
      AND legacy.provider = 'openai'
      AND kept.user_id = legacy.user_id
    """)

    execute("UPDATE oauth_tokens SET provider = 'openai' WHERE provider = 'openai_codex'")
  end
end
