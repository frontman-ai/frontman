defmodule FrontmanServer.Repo.Migrations.AddNewUserNotifyTrigger do
  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION notify_new_user() RETURNS trigger AS $$
    BEGIN
      PERFORM pg_notify(
        'new_user',
        json_build_object(
          'id', NEW.id,
          'email', NEW.email,
          'name', NEW.name,
          'inserted_at', NEW.inserted_at
        )::text
      );
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER users_after_insert_notify
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_user();
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS users_after_insert_notify ON users;")
    execute("DROP FUNCTION IF EXISTS notify_new_user();")
  end
end
