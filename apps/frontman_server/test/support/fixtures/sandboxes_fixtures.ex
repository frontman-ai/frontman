defmodule FrontmanServer.Test.Fixtures.Sandboxes do
  @moduledoc "Test helpers for creating sandbox entities."

  import FrontmanServer.Test.Fixtures.Projects

  alias FrontmanServer.Tasks

  def valid_env_spec do
    %{"runtime" => "node20", "package_manager" => "pnpm", "port" => 3000}
  end

  def task_with_project_fixture(scope) do
    project = project_fixture(scope)
    task_id = Ecto.UUID.generate()
    {:ok, ^task_id} = Tasks.create_task(scope, task_id)

    task =
      FrontmanServer.Tasks.TaskSchema
      |> FrontmanServer.Repo.get!(task_id)
      |> Ecto.Changeset.change(project_id: project.id)
      |> FrontmanServer.Repo.update!()

    task
  end
end
