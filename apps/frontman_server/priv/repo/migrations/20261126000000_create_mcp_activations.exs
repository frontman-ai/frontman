defmodule FrontmanServer.Repo.Migrations.CreateMcpActivations do
  use Ecto.Migration

  def change do
    create table(:mcp_activations, primary_key: false) do
      add(:event_id, :uuid, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:client_key, :text, null: false)
      add(:inserted_at, :utc_datetime_usec, null: false)
    end

    # The empty client key is the user milestone; hashed keys are user/client milestones.
    create(unique_index(:mcp_activations, [:user_id, :client_key]))
  end
end
