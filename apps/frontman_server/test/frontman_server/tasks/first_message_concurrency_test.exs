defmodule FrontmanServer.Tasks.FirstMessageConcurrencyTest do
  use ExUnit.Case, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks

  test "two barrier-synchronized accepted prompts retain one first observation" do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()

      try do
        task_id = task_fixture(scope).id
        parent = self()

        submissions =
          for _ <- 1..2 do
            Task.async(fn ->
              Sandbox.unboxed_run(Repo, fn ->
                send(parent, {:ready, self()})

                receive do
                  :submit ->
                    result =
                      Tasks.submit_user_message(scope, %{
                        task_id: task_id,
                        message_id: Ecto.UUID.generate(),
                        message: [%{"type" => "text", "text" => "hello"}],
                        model: "openrouter:openai/gpt-5.5",
                        agent_id: "test-frontman"
                      })

                    {result, Repo.reload!(Scope.user(scope)).first_message_at}
                after
                  1_000 -> raise "timed out waiting to submit prompt"
                end
              end)
            end)
          end

        assert_receive {:ready, _}, 1_000
        assert_receive {:ready, _}, 1_000
        Enum.each(submissions, &send(&1.pid, :submit))
        results = Enum.map(submissions, &Task.await(&1, 5_000))
        observed_at = Repo.reload!(Scope.user(scope)).first_message_at
        assert %DateTime{} = observed_at
        Enum.each(results, fn {{:ok, _}, timestamp} -> assert timestamp == observed_at end)
      after
        Repo.delete!(Scope.user(scope))
      end
    end)
  end
end
