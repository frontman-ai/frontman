defmodule FrontmanServer.Repo.Migrations.ScrubToolResultMetadata do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE interactions
    SET data = jsonb_set(
      data,
      '{result}',
      jsonb_build_object(
        'content', COALESCE(data->'result'->'content', '[]'::jsonb),
        'isError', CASE WHEN data->>'is_error' = 'true' THEN true ELSE false END,
        '_meta', '{}'::jsonb
      ) || CASE
        WHEN data->'result' ? 'structuredContent'
          AND data->'result'->'structuredContent' <> 'null'::jsonb
          THEN jsonb_build_object(
            'structuredContent', data->'result'->'structuredContent'
          )
        ELSE '{}'::jsonb
      END,
      true
    )
    WHERE type = 'tool_result'
    """)
  end

  def down, do: :ok
end
