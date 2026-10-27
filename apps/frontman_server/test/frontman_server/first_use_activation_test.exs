defmodule FrontmanServer.FirstUseActivationTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: FrontmanServer.Repo

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks
  import FrontmanServer.BillingFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.FirstUseActivation
  alias FrontmanServer.Repo
  alias FrontmanServer.RestartResources
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Workers.SyncResendContact

  test "requires a transaction and rolls back the milestone and job with its caller" do
    with_owned_task(fn scope, _task_id ->
      assert_raise ArgumentError, ~r/requires the acceptance transaction/, fn ->
        FirstUseActivation.record(scope)
      end

      assert {:error, :rejected} =
               Repo.transact(fn ->
                 assert :ok = FirstUseActivation.record(scope)
                 assert Repo.reload!(Scope.user(scope)).first_message_at
                 assert [_] = activation_jobs(scope)
                 {:error, :rejected}
               end)

      assert Repo.reload!(Scope.user(scope)).first_message_at == nil
      assert activation_jobs(scope) == []
    end)
  end

  test "concurrent first prompts on independent connections persist exactly one activation" do
    with_owned_task(fn scope, task_id ->
      parent = self()

      tasks =
        for _ <- 1..2 do
          Task.async(fn ->
            Sandbox.unboxed_run(Repo, fn ->
              %{rows: [[connection_id]]} = Repo.query!("SELECT pg_backend_pid()")
              send(parent, {:ready, connection_id})

              receive do
                :accept -> submit(scope, task_id)
              after
                5_000 -> raise "timed out waiting to accept first prompt"
              end
            end)
          end)
        end

      assert_receive {:ready, first_connection}, 5_000
      assert_receive {:ready, second_connection}, 5_000
      refute first_connection == second_connection
      Enum.each(tasks, &send(&1.pid, :accept))
      Enum.each(tasks, fn task -> assert {:ok, _} = Task.await(task, 10_000) end)

      assert Repo.aggregate(InteractionSchema.for_task(task_id), :count) == 2
      assert %DateTime{} = observed_at = Repo.reload!(Scope.user(scope)).first_message_at
      assert [%{args: %{"activation" => true, "user_id" => user_id}}] = activation_jobs(scope)
      assert user_id == Scope.user_id(scope)

      assert {:ok, _} = submit(scope, task_id)
      assert Repo.reload!(Scope.user(scope)).first_message_at == observed_at
      assert [_] = activation_jobs(scope)
    end)
  end

  defp with_owned_task(callback) do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()
      task_id = Ecto.UUID.generate()

      try do
        allow_access_for_scope_fixture(scope)
        {:ok, _} = Tasks.create_task(scope, task_id, "nextjs")
        callback.(scope, task_id)
      after
        RestartResources.delete_jobs(scope, task_id)
        Repo.delete!(Scope.user(scope))
      end
    end)
  end

  defp submit(scope, task_id) do
    Tasks.submit_user_message(scope, %{
      task_id: task_id,
      message_id: Ecto.UUID.generate(),
      message: user_content("first prompt"),
      model: "openrouter:openai/gpt-5.5",
      agent_id: "test-frontman"
    })
  end

  defp activation_jobs(scope) do
    all_enqueued(
      worker: SyncResendContact,
      args: %{user_id: Scope.user_id(scope), activation: true}
    )
  end
end
