defmodule FrontmanServer.Workers.GenerateTitleTest do
  use FrontmanServer.DataCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.AccountsFixtures

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Workers.GenerateTitle

  setup do
    user = user_fixture()
    {:ok, user: user}
  end

  describe "new_job/3" do
    test "builds a job changeset with the correct args", %{user: user} do
      changeset = GenerateTitle.new_job(user.id, "task-123", "Help me build a login page")

      assert changeset.changes.args == %{
               user_id: user.id,
               task_id: "task-123",
               user_prompt_text: "Help me build a login page"
             }
    end
  end

  describe "perform/1" do
    test "enqueues via Tasks context", %{user: user} do
      scope = Scope.for_user(user)
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, _job} =
        Tasks.enqueue_title_generation(scope, task_id, "Help me build a login page")

      assert_enqueued(
        worker: GenerateTitle,
        args: %{user_id: user.id, task_id: task_id}
      )
    end
  end
end
