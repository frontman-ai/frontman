defmodule FrontmanServer.Workers.GenerateTitleTest do
  use FrontmanServer.DataCase, async: true
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers.Model
  alias FrontmanServer.Tasks
  alias FrontmanServer.Workers.GenerateTitle

  setup do
    user = user_fixture()
    {:ok, user: user}
  end

  describe "new_job/4" do
    test "builds a job changeset with model and encrypted env_api_key", %{user: user} do
      scope =
        user
        |> Scope.for_user()
        |> Scope.with_env_api_keys(%{"anthropic" => "sk-test-123"})

      changeset =
        GenerateTitle.new_job(
          scope,
          "task-123",
          "Help me build a login page",
          "anthropic:claude-sonnet-4-20250514"
        )

      args = changeset.changes.args
      assert args.user_id == user.id
      assert args.task_id == "task-123"
      assert args.user_prompt_text == "Help me build a login page"
      assert args.model == "anthropic:claude-sonnet-4-20250514"
      assert is_binary(args.encrypted_env_api_key)
      refute Map.has_key?(args, :env_api_key)
    end

    test "stores nil encrypted_env_api_key when env keys are empty", %{user: user} do
      scope = Scope.for_user(user)
      changeset = GenerateTitle.new_job(scope, "task-123", "Hello", nil)

      assert changeset.changes.args.encrypted_env_api_key == nil
    end
  end

  describe "perform/1" do
    test "enqueues via Tasks context with forwarded model and encrypted env key", %{user: user} do
      scope =
        user
        |> Scope.for_user()
        |> Scope.with_env_api_keys(%{"openrouter" => "sk-or-test"})

      task_id = task_fixture(scope)

      {:ok, _job} =
        Tasks.enqueue_title_generation(scope, task_id, "Help me build a login page",
          model: Model.new("openrouter", "openai/gpt-5.5")
        )

      assert_enqueued(
        worker: GenerateTitle,
        args: %{
          user_id: user.id,
          task_id: task_id,
          model: "openrouter:openai/gpt-5.5"
        }
      )
    end
  end
end
