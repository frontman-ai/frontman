defmodule FrontmanServer.Repo.Migrations.NormalizeFrameworks do
  use Ecto.Migration

  def up do
    execute("UPDATE tasks SET framework = 'nextjs'    WHERE framework = 'Next.js'")
    execute("UPDATE tasks SET framework = 'vite'      WHERE framework = 'Vite'")
    execute("UPDATE tasks SET framework = 'astro'     WHERE framework = 'Astro'")
    execute("UPDATE tasks SET framework = 'wordpress' WHERE framework = 'wordpress'")

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
