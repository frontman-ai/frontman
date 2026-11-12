defmodule FrontmanServer.Repo.Migrations.RenameRunAllowancesToTasks do
  use Ecto.Migration

  def change do
    rename table(:billing_run_allowances), to: table(:tasks_run_allowances)
  end
end
