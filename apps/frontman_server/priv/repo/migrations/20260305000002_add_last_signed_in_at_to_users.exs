defmodule FrontmanServer.Repo.Migrations.AddLastSignedInAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:last_signed_in_at, :utc_datetime)
    end
  end
end
