defmodule FrontmanServer.Repo.Migrations.CreateSandboxes do
  use Ecto.Migration

  def change do
    create table(:sandboxes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider_ref, :string
      add :status, :string
      add :vm_ip, :string
      add :port_map, :map
      add :preview_url, :string
      add :env_spec, :map
      add :last_active_at, :utc_datetime
      add :task_id, references(:tasks, on_delete: :nothing, type: :binary_id)
      add :project_id, references(:projects, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:sandboxes, [:task_id])
    create index(:sandboxes, [:project_id])
  end
end
