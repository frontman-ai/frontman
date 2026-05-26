defmodule FrontmanServer.Repo.Migrations.DeleteLegacySpawnInteractions do
  use Ecto.Migration

  def up do
    execute("DELETE FROM interactions WHERE type = 'agent_spawned'")
  end

  def down do
    :ok
  end
end
