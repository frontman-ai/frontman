defmodule FrontmanServer.Workers.GenerateTitleTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Workers.GenerateTitle

  setup do
    user = user_fixture()
    {:ok, user: user}
  end

  describe "new_job/4" do
    test "builds a job changeset with model", %{user: user} do
      scope = Scope.for_user(user)

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

      assert MapSet.new(Map.keys(args)) ==
               MapSet.new([:model, :task_id, :user_id, :user_prompt_text])
    end
  end
end
