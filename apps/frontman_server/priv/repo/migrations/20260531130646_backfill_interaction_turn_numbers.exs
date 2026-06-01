defmodule FrontmanServer.Repo.Migrations.BackfillInteractionTurnNumbers do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    DECLARE
      scoped_types text[] := ARRAY['user_message', 'agent_response', 'tool_call', 'tool_result', 'agent_completed', 'agent_error', 'agent_paused', 'agent_retry'];
      orphan_count integer;
    BEGIN
      WITH numbered AS (
        SELECT id, type,
          (count(*) FILTER (WHERE type = 'user_message') OVER (
            PARTITION BY task_id
            ORDER BY coalesce(sequence, 0), inserted_at, id
          ))::integer AS turn_number
        FROM interactions
      ),
      updated AS (
        UPDATE interactions AS i
        SET turn_number = n.turn_number
        FROM numbered AS n
        WHERE i.id = n.id
          AND n.turn_number > 0
          AND n.type = ANY (scoped_types)
          AND i.turn_number IS NULL
        RETURNING i.id
      )
      SELECT count(*) INTO orphan_count
      FROM numbered
      WHERE turn_number = 0
        AND type = ANY (scoped_types);

      IF orphan_count > 0 THEN
        RAISE WARNING 'Found % turn-scoped interactions before any user_message; leaving turn_number NULL', orphan_count;
      END IF;
    END $$;
    """)
  end

  def down, do: :ok
end
