defmodule FrontmanServer.CustomerFeedbackConcurrencyTest do
  use ExUnit.Case, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.CustomerFeedback
  alias FrontmanServer.CustomerFeedback.Feedback
  alias FrontmanServer.Repo

  test "concurrent answers return the same first stored answer" do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()

      try do
        interaction = insert_accepted_user_message!(task_fixture(scope), "Feedback checkpoint")
        {:ok, _} = CustomerFeedback.record_request(scope, interaction)
        parent = self()

        tasks =
          for score <- [0, 10] do
            Task.async(fn ->
              Sandbox.unboxed_run(Repo, fn ->
                send(parent, {:ready, self()})

                receive do
                  :answer ->
                    CustomerFeedback.record_answer(scope, interaction.id, %{score: score})
                after
                  1_000 -> raise "timed out waiting to answer customer feedback"
                end
              end)
            end)
          end

        assert_receive {:ready, _}, 1_000
        assert_receive {:ready, _}, 1_000
        Enum.each(tasks, &send(&1.pid, :answer))

        assert [{:ok, first}, {:ok, second}] = Enum.map(tasks, &Task.await(&1, 5_000))
        assert first == second
        assert first.score in [0, 10]
        assert first.answered_at
        assert Repo.get!(Feedback, first.id) == first
      after
        Repo.delete!(Scope.user(scope))
      end
    end)
  end
end
