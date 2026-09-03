defmodule FrontmanServer.Repo.Migrations.CreateSkills do
  use Ecto.Migration

  def change do
    create table(:skills, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text, null: false
      add :content, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:skills, [:name])

    create constraint(:skills, :skills_name_format,
             check: "name ~ '^[a-z0-9][a-z0-9_-]*$' AND name = lower(name)"
           )
  end
end
