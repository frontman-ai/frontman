defmodule FrontmanServer.Repo.Migrations.AlterTasksAddProjectAndBranch do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      # Nullable: legacy tasks have no project yet
      add :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
      # Agent-created branch name, e.g. frontman/task-{id}; null for legacy tasks
      add :branch, :string
    end

    create index(:tasks, [:project_id])
  end
end
