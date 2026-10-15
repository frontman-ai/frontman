defmodule FrontmanServer.Tasks.PretrialConcurrencyTest do
  use FrontmanServer.ExecutionCase

  import Ecto.Query
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.{Billing, Repo, Tasks}

  test "independent transactions compete for the final user-wide turn" do
    Sandbox.mode(Repo, :auto)
    on_exit(fn -> Sandbox.mode(Repo, :manual) end)
    stub_llm_response("Done")
    scope = user_scope_fixture()
    tasks = for _ <- 1..2, do: task_fixture(scope)

    try do
      for _ <- 1..4, do: :ok = Billing.consume_pretrial_run(scope)
      for task <- tasks, do: insert_accepted_user_message!(task, "Edit")
      parent = self()

      claims =
        for task <- tasks do
          Task.async(fn ->
            send(parent, {:ready, self()})

            receive do
              :claim -> Tasks.execute_next_turn(scope, task.id, execution_request_fixture())
            after
              1_000 -> raise "Timed out waiting to claim turn"
            end
          end)
        end

      for _ <- claims, do: assert_receive({:ready, _}, 1_000)
      Enum.each(claims, &send(&1.pid, :claim))

      assert Enum.sort(Enum.map(claims, &Task.await(&1, 5_000))) == [
               :ok,
               {:error, :billing_inactive}
             ]

      assert %{pretrial_runs_remaining: 0} = Billing.status(scope)

      completed =
        for task <- tasks do
          refute_running_eventually(task.id)
          {:ok, history} = Tasks.get_task_with_history(scope, task.id)
          Enum.count(history.interaction_rows, &(&1.type == :agent_completed))
        end

      assert Enum.sort(completed) == [0, 1]
    after
      for task <- tasks, do: refute_running_eventually(task.id)
      Repo.delete_all(from job in Oban.Job, where: job.args["user_id"] == ^scope.user.id)
      Repo.delete!(scope.user)
    end
  end
end
