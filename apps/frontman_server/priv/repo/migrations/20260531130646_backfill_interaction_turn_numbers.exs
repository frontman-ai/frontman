defmodule FrontmanServer.Repo.Migrations.BackfillInteractionTurnNumbers do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    DECLARE
      scoped_types text[] := ARRAY['user_message', 'agent_response', 'tool_call', 'tool_result', 'agent_completed', 'agent_error', 'agent_paused', 'agent_retry'];
      legacy_sequence_cutoff bigint := 1000000000000;
      orphan_count integer;
      remaining_count integer;
    BEGIN
      WITH legacy_rows AS (
        SELECT id,
          floor(
            extract(epoch FROM coalesce(
              nullif(data->>'timestamp', '')::timestamptz,
              inserted_at AT TIME ZONE 'UTC'
            )) * 1000000
          )::bigint AS event_us,
          task_id,
          inserted_at,
          sequence
        FROM interactions
        WHERE sequence IS NULL
           OR sequence < legacy_sequence_cutoff
      ),
      repaired AS (
        SELECT id,
          event_us + row_number() OVER (
            PARTITION BY task_id, event_us
            ORDER BY inserted_at, sequence NULLS LAST, id
          ) - 1 AS repaired_sequence
        FROM legacy_rows
      )
      UPDATE interactions AS i
      SET sequence = repaired.repaired_sequence
      FROM repaired
      WHERE i.id = repaired.id;

      CREATE TEMP TABLE interaction_turn_backfill_numbered ON COMMIT DROP AS
        SELECT id, type,
          (count(*) FILTER (WHERE type = 'user_message') OVER (
            PARTITION BY task_id
            ORDER BY sequence, inserted_at, id
          ))::integer AS turn_number
        FROM interactions
        WHERE type = ANY (scoped_types);

      SELECT count(*) INTO orphan_count
      FROM interaction_turn_backfill_numbered
      WHERE turn_number = 0;

      IF orphan_count > 0 THEN
        RAISE EXCEPTION 'Found % turn-scoped interactions before any user_message; refusing unsafe turn_number backfill', orphan_count;
      END IF;

      UPDATE interactions AS i
      SET turn_number = n.turn_number
      FROM interaction_turn_backfill_numbered AS n
      WHERE i.id = n.id
        AND n.turn_number > 0
        AND i.turn_number IS NULL;

      SELECT count(*) INTO remaining_count
      FROM interactions
      WHERE type = ANY (scoped_types)
        AND turn_number IS NULL;

      IF remaining_count > 0 THEN
        RAISE EXCEPTION 'Backfill left % turn-scoped interactions without turn_number', remaining_count;
      END IF;
    END $$;
    """)
  end

  def down, do: :ok
end
