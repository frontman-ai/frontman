defmodule FrontmanServer.Repo.Migrations.BackfillAgentAttribution do
  use Ecto.Migration

  @agent_id "01987f6e-2c6d-7f0c-9a0e-7a4b3d2c1f09"

  def up do
    execute("""
    UPDATE interactions
    SET data = (data #>> '{}')::jsonb
    WHERE type = 'turn_started'
      AND jsonb_typeof(data) = 'string'
    """)

    execute("""
    UPDATE interactions
    SET data = jsonb_set(data, '{agent_id}', to_jsonb('#{@agent_id}'::text), true)
    WHERE type = 'user_message'
      AND COALESCE(data->>'agent_id', '') = ''
    """)

    execute("""
    UPDATE interactions
    SET data = jsonb_set(data, '{agent_id}', to_jsonb('#{@agent_id}'::text), true)
    WHERE type = 'turn_started'
      AND COALESCE(data->>'agent_id', '') = ''
    """)

    execute("""
    WITH ordered_turns AS (
      SELECT
        id,
        task_id,
        sequence,
        lag(sequence) OVER (
          PARTITION BY task_id
          ORDER BY sequence, inserted_at, id
        ) AS previous_turn_sequence
      FROM interactions
      WHERE type = 'turn_started'
    ),
    missing_links AS (
      SELECT
        turn.id,
        jsonb_agg(to_jsonb(message.id::text) ORDER BY message.sequence, message.inserted_at, message.id) AS user_message_ids
      FROM ordered_turns turn
      JOIN interactions message
        ON message.task_id = turn.task_id
        AND message.type = 'user_message'
        AND message.sequence > COALESCE(turn.previous_turn_sequence, -1)
        AND message.sequence <= turn.sequence
      JOIN interactions stored_turn ON stored_turn.id = turn.id
      WHERE NOT (stored_turn.data ? 'user_message_ids')
        OR jsonb_array_length(stored_turn.data->'user_message_ids') = 0
      GROUP BY turn.id
    )
    UPDATE interactions turn
    SET data = jsonb_set(turn.data, '{user_message_ids}', missing_links.user_message_ids, true)
    FROM missing_links
    WHERE turn.id = missing_links.id
    """)
  end

  def down, do: :ok
end
