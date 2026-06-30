defmodule FrontmanServer.Repo.Migrations.BackfillTurnStartedForUserMessages do
  use Ecto.Migration

  def up do
    repo = repo()

    %{rows: rows} =
      repo.query!("""
      SELECT
        task_id::text,
        turn_number,
        array_agg(id::text ORDER BY sequence, inserted_at, id),
        min(sequence),
        min(inserted_at)
      FROM interactions i
      WHERE type = 'user_message'
        AND turn_number IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM interactions existing
          WHERE existing.task_id = i.task_id
            AND existing.type = 'turn_started'
            AND existing.turn_number = i.turn_number
        )
      GROUP BY task_id, turn_number
      """)

    Enum.each(rows, fn [task_id, turn_number, user_message_ids, sequence, inserted_at] ->
      data =
        Jason.encode!(%{
          "__type__" => "turn_started",
          "id" => Ecto.UUID.generate(),
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "user_message_ids" => user_message_ids
        })

      repo.query!(
        """
        INSERT INTO interactions (id, task_id, type, data, turn_number, sequence, inserted_at)
        VALUES ($1::uuid, $2::uuid, 'turn_started', $3::jsonb, $4, $5, $6)
        """,
        [
          Ecto.UUID.dump!(Ecto.UUID.generate()),
          Ecto.UUID.dump!(task_id),
          data,
          turn_number,
          sequence,
          inserted_at
        ]
      )
    end)

    execute("""
    UPDATE interactions
    SET turn_number = NULL
    WHERE type = 'user_message'
      AND turn_number IS NOT NULL
    """)
  end

  def down do
    :ok
  end
end
