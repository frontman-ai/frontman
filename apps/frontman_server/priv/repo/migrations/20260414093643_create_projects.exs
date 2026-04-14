defmodule FrontmanServer.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :github_repo, :string, null: false
      add :default_branch, :string, null: false
      add :framework, :string
      add :last_env_spec, :map

      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:user_id])
  end
end
