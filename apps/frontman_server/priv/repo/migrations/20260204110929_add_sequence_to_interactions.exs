defmodule FrontmanServer.Repo.Migrations.AddSequenceToInteractions do
  use Ecto.Migration

  def change do
    alter table(:interactions) do
      # Monotonic sequence number for deterministic ordering within a task.
      # Generated client-side at interaction creation time to avoid DB race conditions.
      # Uses bigint to accommodate microsecond timestamps (System.monotonic_time(:microsecond)).
      add(:sequence, :bigint)
    end

    # Index for efficient ordering queries
    create(index(:interactions, [:task_id, :sequence]))
  end
end
