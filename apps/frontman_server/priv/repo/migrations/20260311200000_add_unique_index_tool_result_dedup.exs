defmodule FrontmanServer.Repo.Migrations.AddUniqueIndexToolResultDedup do
  use Ecto.Migration

  def up do
    # Prevent duplicate tool_result interactions for the same tool_call_id within a task.
    # Uses raw SQL because Ecto's unique_index DSL does not support expression columns.
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
