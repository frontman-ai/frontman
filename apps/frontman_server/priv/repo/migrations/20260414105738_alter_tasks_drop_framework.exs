defmodule FrontmanServer.Repo.Migrations.AlterTasksDropFramework do
  use Ecto.Migration

  # Framework is a project-level concern, not a per-task concern.
  # New tasks derive framework from their project. Legacy tasks lose this field;
  # they can be re-associated with a project to regain framework context.
  def change do
    alter table(:tasks) do
      remove :framework, :string
    end
  end
end
