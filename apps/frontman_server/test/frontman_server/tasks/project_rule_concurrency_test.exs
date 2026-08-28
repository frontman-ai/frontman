defmodule FrontmanServer.Tasks.ProjectRuleConcurrencyTest do
  use ExUnit.Case, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.InteractionSchema

  test "serializes concurrent batches against the durable limit" do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()

      try do
        task_id = task_fixture(scope).id
        parent = self()

        tasks =
          for prefix <- ["first", "second"] do
            Task.async(fn ->
              Sandbox.unboxed_run(Repo, fn ->
                send(parent, {:ready, self()})

                receive do
                  :insert -> insert_rules(scope, task_id, prefix)
                after
                  1_000 -> raise "timed out waiting to insert project rules"
                end
              end)
            end)
          end

        assert_receive {:ready, _task_pid}, 1_000
        assert_receive {:ready, _task_pid}, 1_000
        Enum.each(tasks, &send(&1.pid, :insert))

        results = Enum.map(tasks, &Task.await(&1, 5_000))

        assert Enum.sort(results) == [:inserted, :rejected]
        assert Repo.aggregate(InteractionSchema.for_task(task_id), :count) == 32
      after
        Repo.delete!(Scope.user(scope))
      end
    end)
  end

  defp insert_rules(scope, task_id, prefix) do
    rules = Enum.map(1..32, &{"#{prefix}-#{&1}", "content"})

    try do
      {:ok, _rules} = Tasks.add_discovered_project_rules(scope, task_id, rules)
      :inserted
    rescue
      error in RuntimeError ->
        assert error.message =~ "project rule count 64 exceeded limit 32"
        :rejected
    end
  end
end
