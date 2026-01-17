defmodule FrontmanServer.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :short_desc, :string, null: false
      add :framework, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:user_id])

    create table(:interactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :data, :jsonb, null: false, default: "{}"

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:interactions, [:task_id])
  end
end
