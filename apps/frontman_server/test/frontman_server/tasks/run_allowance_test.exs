defmodule FrontmanServer.Tasks.RunAllowanceTest do
  use ExUnit.Case, async: true

  import Ecto.Query
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks, only: [task_fixture: 1]

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.{Repo, Tasks}
  alias FrontmanServer.Tasks.RunAllowance

  test "concurrent consumption on independent connections admits exactly five runs" do
    Sandbox.unboxed_run(Repo, fn ->
      user = unconfirmed_user_fixture()
      other_user = unconfirmed_user_fixture()
      scope = Scope.for_user(user)

      try do
        task = task_fixture(scope)

        results =
          Task.async_stream(
            1..12,
            fn _ ->
              Sandbox.unboxed_run(Repo, fn ->
                Repo.insert_all(RunAllowance, [%{user_id: user.id, used: 1}],
                  conflict_target: :user_id,
                  on_conflict: RunAllowance.increment_below(5)
                )
              end)
            end,
            max_concurrency: 12,
            timeout: 5_000
          )
          |> Enum.map(fn {:ok, result} -> result end)

        assert Enum.count(results, &(&1 == {1, nil})) == 5
        assert Enum.count(results, &(&1 == {0, nil})) == 7
        assert :ok = Tasks.delete_task(scope, task.id)
        assert Tasks.remaining_runs(scope) == 0
        assert Tasks.remaining_runs(Scope.for_user(other_user)) == 5
      after
        Repo.delete_all(
          from job in Oban.Job, where: job.args["user_id"] in ^[user.id, other_user.id]
        )

        Repo.delete!(user)
        Repo.delete!(other_user)
      end
    end)
  end
end
