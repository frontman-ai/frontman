defmodule FrontmanServer.Repo.Migrations.ScrubToolResultMetadata do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE interactions
    SET data = jsonb_set(
      data,
      '{result,_meta}',
      '{}'::jsonb,
      true
    )
    WHERE type = 'tool_result'
      AND jsonb_typeof(data->'result') = 'object'
    """)
  end

  def down, do: :ok
end
