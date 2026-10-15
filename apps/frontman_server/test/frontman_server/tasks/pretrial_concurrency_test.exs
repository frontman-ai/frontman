defmodule FrontmanServer.Tasks.PretrialConcurrencyTest do
  use FrontmanServer.ExecutionCase

  import Ecto.Query
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.{Billing, Repo, Tasks}

  test "independent transactions compete for the final user-wide turn" do
    stub_llm_response("Done")

    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()
      tasks = for _ <- 1..2, do: task_fixture(scope)

      try do
        execution = execution_request_fixture()
        for _ <- 1..4, do: :ok = Billing.consume_pretrial_run(scope)

        for task <- tasks do
          assert {:ok, _} =
                   Tasks.submit_user_message(
                     scope,
                     Map.merge(execution, %{
                       task_id: task.id,
                       message_id: Ecto.UUID.generate(),
                       message: user_content("Edit")
                     })
                   )
        end

        parent = self()

        claims =
          for task <- tasks do
            Task.async(fn ->
              Sandbox.unboxed_run(Repo, fn ->
                send(parent, {:ready, self()})

                receive do
                  :claim -> Tasks.execute_next_turn(scope, task.id, execution)
                after
                  1_000 -> raise "Timed out waiting to claim turn"
                end
              end)
            end)
          end

        for _ <- claims, do: assert_receive({:ready, _}, 1_000)
        Enum.each(claims, &send(&1.pid, :claim))
        results = Enum.map(claims, &Task.await(&1, 5_000))
        assert Enum.sort(results) == Enum.sort([:ok, {:error, :billing_inactive}])
        assert %{pretrial_runs_remaining: 0} = Billing.status(scope)

        turns =
          for task <- tasks do
            refute_running_eventually(task.id)
            {:ok, history} = Tasks.get_task_with_history(scope, task.id)
            Enum.count(history.interaction_rows, &(&1.type == :turn_started))
          end

        assert Enum.sort(turns) == [0, 1]
      after
        for task <- tasks, do: refute_running_eventually(task.id)
        Repo.delete_all(from job in Oban.Job, where: job.args["user_id"] == ^scope.user.id)
        Repo.delete!(scope.user)
      end
    end)
  end
end
