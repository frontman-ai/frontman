defmodule FrontmanServer.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :github_repo, :string
      add :default_branch, :string
      add :framework, :string
      add :last_env_spec, :map
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:user_id])
  end
end
