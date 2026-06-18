defmodule FrontmanServer.Repo.Migrations.BackfillUserMessageModels do
  use Ecto.Migration

  @legacy_default_model "openrouter:google/gemini-3-flash-preview"

  def up do
    execute("""
    UPDATE interactions
    SET data = jsonb_set(data, '{model}', to_jsonb('#{@legacy_default_model}'::text), true)
    WHERE type = 'user_message'
      AND NOT (data ? 'model')
    """)
  end

  def down do
    :ok
  end
end
