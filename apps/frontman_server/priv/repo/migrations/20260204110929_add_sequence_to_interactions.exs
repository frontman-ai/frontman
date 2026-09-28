defmodule FrontmanServer.Repo.Migrations.AddSequenceToInteractions do
  use Ecto.Migration

  def change do
    alter table(:interactions) do
      add(:sequence, :bigint)
    end

    create(index(:interactions, [:task_id, :sequence]))
  end
end
