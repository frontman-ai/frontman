defmodule FrontmanServer.Repo.Migrations.AddFirstMessageAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :first_message_at, :utc_datetime
    end
  end
end
