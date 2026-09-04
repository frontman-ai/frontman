defmodule FrontmanServer.Repo.Migrations.AddCurrentModelToTasks do
  use Ecto.Migration

  def change do
    alter table(:tasks) do
      add(:current_model, :string)
    end
  end
end
