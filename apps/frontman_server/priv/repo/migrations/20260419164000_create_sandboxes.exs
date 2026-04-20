defmodule FrontmanServer.Repo.Migrations.CreateSandboxes do
  use Ecto.Migration

  def change do
    create table(:sandboxes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider_ref, :text
      add :status, :string, null: false, default: "provisioning"
      add :vm_ip, :text
      add :port_map, :map
      add :preview_url, :text
      add :env_spec, :map, null: false
      add :last_active_at, :utc_datetime
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:sandboxes, [:task_id])
    create index(:sandboxes, [:status])
  end
end
