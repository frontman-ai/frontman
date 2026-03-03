defmodule FrontmanServer.Repo.Migrations.NormalizeFrameworks do
  @moduledoc """
  Normalize framework display labels to internal identifiers.

  The framework middleware used to send display labels like "Next.js" which were
  stored directly in the database. Now we normalize to lowercase identifiers
  ("nextjs", "vite", "astro") at the channel ingestion boundary, and this
  migration cleans up existing rows.
  """
  use Ecto.Migration

  def up do
    # Normalize known display labels to IDs
    execute("UPDATE tasks SET framework = 'nextjs'    WHERE framework = 'Next.js'")
    execute("UPDATE tasks SET framework = 'vite'      WHERE framework = 'Vite'")
    execute("UPDATE tasks SET framework = 'astro'     WHERE framework = 'Astro'")
    execute("UPDATE tasks SET framework = 'wordpress' WHERE framework = 'wordpress'")

    # Verify no unknown frameworks remain — crash the migration if so.
    # If this fails, investigate what unexpected values exist before proceeding.
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM tasks
        WHERE framework NOT IN ('nextjs', 'vite', 'astro', 'wordpress')
           OR framework IS NULL
      ) THEN
        RAISE EXCEPTION 'Found tasks with unrecognized framework values. '
          'Run: SELECT DISTINCT framework FROM tasks WHERE framework NOT IN (''nextjs'', ''vite'', ''astro'', ''wordpress'') '
          'to investigate before migrating.';
      END IF;
    END $$;
    """)
  end

  def down do
    execute("UPDATE tasks SET framework = 'Next.js' WHERE framework = 'nextjs'")
    execute("UPDATE tasks SET framework = 'Vite'    WHERE framework = 'vite'")
    execute("UPDATE tasks SET framework = 'Astro'   WHERE framework = 'astro'")
  end
end
