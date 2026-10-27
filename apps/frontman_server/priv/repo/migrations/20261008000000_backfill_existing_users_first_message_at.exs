defmodule FrontmanServer.Repo.Migrations.BackfillExistingUsersFirstMessageAt do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE users
    SET first_message_at = date_trunc('second', timezone('UTC', statement_timestamp()))
    WHERE first_message_at IS NULL
    """)
  end

  @doc "Backfilled timestamps cannot be distinguished safely from recorded first prompts."
  def down, do: :ok
end
