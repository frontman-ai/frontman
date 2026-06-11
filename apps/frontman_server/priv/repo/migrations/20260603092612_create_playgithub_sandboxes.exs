defmodule FrontmanServer.Repo.Migrations.CreatePlaygithubSandboxes do
  use Ecto.Migration

  def change do
    create table(:playgithub_sandboxes, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:github_url, :string, null: false)
      add(:daytona_sandbox_id, :string)
      add(:status, :string, null: false)
      add(:status_started_at, :utc_datetime)
      add(:status_error, :string)

      timestamps(type: :utc_datetime)
    end

    create(index(:playgithub_sandboxes, [:user_id]))

    create(
      unique_index(:playgithub_sandboxes, [:user_id, :github_url],
        name: :playgithub_sandboxes_user_id_github_url_index
      )
    )

    create(
      unique_index(:playgithub_sandboxes, [:daytona_sandbox_id],
        where: "daytona_sandbox_id IS NOT NULL",
        name: :playgithub_sandboxes_daytona_sandbox_id_index
      )
    )
  end
end
