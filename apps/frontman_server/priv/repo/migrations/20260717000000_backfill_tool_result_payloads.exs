defmodule FrontmanServer.Repo.Migrations.BackfillToolResultPayloads do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE interactions
    SET data = jsonb_set(
      data,
      '{result}',
      jsonb_build_object(
        'content', jsonb_build_array(
          jsonb_build_object('type', 'text', 'text', data->>'result')
        ),
        'isError', CASE WHEN data->>'is_error' = 'true' THEN true ELSE false END
      ),
      true
    )
    WHERE type = 'tool_result'
      AND jsonb_typeof(data->'result') = 'string'
    """)
  end

  def down, do: :ok
end
