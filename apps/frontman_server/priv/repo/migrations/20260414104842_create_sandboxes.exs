defmodule FrontmanServer.Repo.Migrations.CreateSandboxes do
  use Ecto.Migration

  def change do
    create table(:sandboxes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false

      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all),
        null: false

      add :provider_ref, :string
      add :status, :string, null: false
      add :vm_ip, :string
      add :port_map, :map
      add :preview_url, :string
      add :env_spec, :map, null: false
      add :last_active_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:sandboxes, [:task_id])
    create index(:sandboxes, [:project_id])
    create index(:sandboxes, [:task_id, :status])

    create constraint(:sandboxes, :valid_status,
             check: "status IN ('provisioning', 'running', 'stopped', 'error')"
           )
  end
end
