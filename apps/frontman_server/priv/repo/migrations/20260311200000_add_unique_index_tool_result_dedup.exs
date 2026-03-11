defmodule FrontmanServer.Repo.Migrations.AddUniqueIndexToolResultDedup do
  use Ecto.Migration

  def change do
    # Prevent duplicate tool_result interactions for the same tool_call_id within a task.
    # The application-level check in Tasks.tool_result_exists?/2 is a fast-path optimization;
    # this index is the authoritative backstop against TOCTOU races.
    create(
      unique_index(
        :interactions,
        [:task_id, fragment("(data->>'tool_call_id')")],
        where: "type = 'tool_result'",
        name: :interactions_tool_result_uniqueness
      )
    )
  end
end
