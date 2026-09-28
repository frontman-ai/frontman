defmodule FrontmanServer.Repo.Migrations.AddUniqueIndexToolResultDedup do
  use Ecto.Migration

  def up do
    execute("""
    CREATE UNIQUE INDEX interactions_tool_result_uniqueness
    ON interactions (task_id, (data->>'tool_call_id'))
    WHERE type = 'tool_result'
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS interactions_tool_result_uniqueness")
  end
end
