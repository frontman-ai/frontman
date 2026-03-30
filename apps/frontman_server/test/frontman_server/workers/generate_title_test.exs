defmodule FrontmanServer.Workers.GenerateTitleTest do
  use FrontmanServer.DataCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.AccountsFixtures

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers.Model
  alias FrontmanServer.Tasks
  alias FrontmanServer.Workers.GenerateTitle

  setup do
    user = user_fixture()
    {:ok, user: user}
  end

  describe "new_job/5" do
    test "builds a job changeset with model and env_api_key", %{user: user} do
      env_api_key = %{"ANTHROPIC_API_KEY" => "sk-test-123"}
      model = "anthropic:claude-sonnet-4-20250514"

      changeset =
        GenerateTitle.new_job(
          user.id,
          "task-123",
          "Help me build a login page",
          model,
          env_api_key
        )

      assert changeset.changes.args == %{
               user_id: user.id,
               task_id: "task-123",
               user_prompt_text: "Help me build a login page",
               model: "anthropic:claude-sonnet-4-20250514",
               env_api_key: %{"ANTHROPIC_API_KEY" => "sk-test-123"}
             }
    end
  end

  describe "perform/1" do
    test "enqueues via Tasks context with forwarded model and env key", %{user: user} do
      scope = Scope.for_user(user)
      task_id = Ecto.UUID.generate()
      {:ok, ^task_id} = Tasks.create_task(scope, task_id, "nextjs")

      {:ok, _job} =
        Tasks.enqueue_title_generation(scope, task_id, "Help me build a login page",
          env_api_key: %{"openrouter" => "sk-or-test"},
          model: Model.new("openrouter", "openai/gpt-5.1-codex")
        )

      assert_enqueued(
        worker: GenerateTitle,
        args: %{
          user_id: user.id,
          task_id: task_id,
          env_api_key: %{"openrouter" => "sk-or-test"},
          model: "openrouter:openai/gpt-5.1-codex"
        }
      )
    end
  end
end
