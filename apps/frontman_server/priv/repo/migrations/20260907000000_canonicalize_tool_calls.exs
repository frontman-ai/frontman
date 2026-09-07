defmodule FrontmanServer.Repo.Migrations.CanonicalizeToolCalls do
  @moduledoc "Backfills canonical calls without application dependencies or changes to original row order."
  use Ecto.Migration

  def up do
    execute("LOCK TABLE interactions IN SHARE ROW EXCLUSIVE MODE")

    execute("""
    UPDATE interactions
    SET data = data || '{"execution_target":"mcp"}'::jsonb
    WHERE type = 'tool_call' AND NOT data ? 'execution_target'
    """)

    create_argument_functions()
    backfill_calls()
    reorder_history()

    create unique_index(:interactions, [:task_id, :turn_number, "(data->>'tool_call_id')"],
             where: "type = 'tool_call'",
             name: :interactions_tool_call_turn_uniqueness
           )
  end

  def down do
    drop index(:interactions, [:task_id, :turn_number, "(data->>'tool_call_id')"],
           name: :interactions_tool_call_turn_uniqueness
         )
  end

  defp create_argument_functions do
    execute("""
    CREATE OR REPLACE FUNCTION pg_temp.strip_tool_nulls(value jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE AS $$
      SELECT CASE WHEN jsonb_typeof(value) = 'object' THEN
        coalesce((SELECT jsonb_object_agg(key, pg_temp.strip_tool_nulls(v))
                  FROM jsonb_each(value) AS fields(key, v) WHERE v <> 'null'::jsonb), '{}')
      ELSE value END
    $$
    """)

    execute("""
    CREATE OR REPLACE FUNCTION pg_temp.tool_arguments(value jsonb) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE AS $$
    BEGIN
      IF jsonb_typeof(value) = 'string' THEN
        IF value #>> '{}' ~ '^[[:space:]]*$' THEN RETURN '{}'::jsonb; END IF;
        BEGIN
          value := (value #>> '{}')::jsonb;
        EXCEPTION WHEN invalid_text_representation THEN
          RETURN 'null'::jsonb;
        END;
      END IF;
      IF jsonb_typeof(value) = 'object' THEN RETURN pg_temp.strip_tool_nulls(value); END IF;
      RETURN 'null'::jsonb;
    END $$
    """)
  end

  defp backfill_calls do
    execute("""
    CREATE TEMP TABLE canonical_tool_call_backfill ON COMMIT DROP AS
    WITH declarations AS (
      SELECT response.id AS anchor_id, response.task_id, response.turn_number,
             response.sequence, response.inserted_at, response.data->>'timestamp' AS timestamp,
             entry->>'id' AS call_id,
             coalesce(entry->>'name', entry#>>'{function,name}') AS name,
             pg_temp.tool_arguments(coalesce(entry->'arguments', entry#>'{function,arguments}')) AS arguments,
             ordinal, 0 AS priority
      FROM interactions response
      CROSS JOIN LATERAL jsonb_array_elements(
        coalesce(nullif(response.data#>'{metadata,tool_calls}', 'null'::jsonb), '[]'::jsonb)
      ) WITH ORDINALITY AS calls(entry, ordinal)
      WHERE response.type = 'agent_response'
      UNION ALL
      SELECT result.id, result.task_id, result.turn_number, result.sequence, result.inserted_at,
             result.data->>'timestamp', result.data->>'tool_call_id', result.data->>'tool_name',
             'null'::jsonb, -1, 1
      FROM interactions result WHERE result.type = 'tool_result'
    ), missing AS (
      SELECT DISTINCT ON (task_id, turn_number, call_id) * FROM declarations declaration
      WHERE NOT EXISTS (
        SELECT 1 FROM interactions call
        WHERE call.type = 'tool_call' AND call.task_id = declaration.task_id
          AND call.turn_number = declaration.turn_number AND call.data->>'tool_call_id' = declaration.call_id
      )
      ORDER BY task_id, turn_number, call_id, priority, sequence, inserted_at, anchor_id, ordinal
    )
    SELECT gen_random_uuid() AS id, *, jsonb_build_object(
      '__type__', 'tool_call', 'tool_call_id', call_id, 'tool_name', name, 'arguments', arguments,
      'execution_target', NULL,
      'timestamp', coalesce(timestamp, to_char(inserted_at, 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))
    ) AS data FROM missing
    """)

    execute("""
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM canonical_tool_call_backfill
                 WHERE call_id IS NULL OR call_id = '' OR name IS NULL OR name = '' OR turn_number IS NULL) THEN
        RAISE EXCEPTION 'Cannot backfill tool calls without identity, name, or turn';
      END IF;
    END $$
    """)

    execute("""
    INSERT INTO interactions (id, task_id, turn_number, type, data, sequence, inserted_at)
    SELECT id, task_id, turn_number, 'tool_call', data || jsonb_build_object('id', id::text), sequence, inserted_at
    FROM canonical_tool_call_backfill
    """)
  end

  defp reorder_history do
    execute("""
    WITH ordered AS (
      SELECT interaction.id, row_number() OVER (
        PARTITION BY interaction.task_id
        ORDER BY anchor.sequence, anchor.inserted_at, anchor.id, coalesce(backfill.ordinal, 0), interaction.id
      ) AS sequence
      FROM interactions interaction
      LEFT JOIN canonical_tool_call_backfill backfill ON backfill.id = interaction.id
      JOIN interactions anchor ON anchor.id = coalesce(backfill.anchor_id, interaction.id)
      WHERE interaction.task_id IN (SELECT task_id FROM canonical_tool_call_backfill)
    )
    UPDATE interactions SET sequence = ordered.sequence FROM ordered WHERE interactions.id = ordered.id
    """)
  end
end
