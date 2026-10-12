defmodule FrontmanServer.CustomerFeedbackConcurrencyTest do
  use ExUnit.Case, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.InteractionSchema

  for name <- ["request_customer_feedback", "ordinary_tool"] do
    test "concurrent #{name} requests reuse one dispatch" do
      with_task(fn scope, task, turn ->
        call = %SwarmAi.ToolCall{id: "same-id", name: unquote(name), arguments: "{}"}

        operations =
          for _ <- 1..2,
              do: fn -> Tasks.request_client_tool(scope, task.id, turn, call, :interactive) end

        assert [{:ok, first}, {:ok, second}] = race(operations)
        assert first == second

        assert Repo.one!(
                 InteractionSchema.for_task(task.id)
                 |> InteractionSchema.of_type(:tool_call)
               ).data == first
      end)
    end
  end

  test "concurrent answers return the same first stored answer" do
    with_task(fn scope, task, turn ->
      call = %SwarmAi.ToolCall{id: "feedback", name: "request_customer_feedback", arguments: "{}"}
      {:ok, _} = Tasks.request_client_tool(scope, task.id, turn, call, :interactive)
      operations = for score <- [0, 10], do: fn -> answer(scope, task.id, call, score) end
      assert [{:ok, first, :no_executor}, {:ok, second, :no_executor}] = race(operations)
      assert first == second
      assert first.result["structuredContent"]["score"] in [0, 10]
      assert first.timestamp

      assert Repo.one!(
               InteractionSchema.for_task(task.id)
               |> InteractionSchema.of_type(:tool_result)
             ).data == first
    end)
  end

  test "an answer racing cancellation returns the single winning result" do
    with_task(fn scope, task, turn ->
      call = %SwarmAi.ToolCall{id: "feedback", name: "request_customer_feedback", arguments: "{}"}
      {:ok, _} = Tasks.request_client_tool(scope, task.id, turn, call, :interactive)

      operations = [
        fn -> Tasks.handle_swarm_event(scope, task.id, turn, {:cancelled, :user}) end,
        fn -> answer(scope, task.id, call, 10) end
      ]

      assert [:ok, {:ok, winner, :no_executor}] = race(operations)

      assert Repo.one!(
               InteractionSchema.for_task(task.id)
               |> InteractionSchema.of_type(:tool_result)
             ).data == winner

      assert Repo.aggregate("customer_feedback", :count) == 0
    end)
  end

  defp answer(scope, task_id, call, score) do
    Tasks.resolve_tool_request(scope, task_id, call, %{
      "content" => [],
      "structuredContent" => %{"outcome" => "answered", "score" => score}
    })
  end

  defp with_task(operation) do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()

      try do
        task = task_fixture(scope)
        operation.(scope, task, start_turn_fixture(scope, task.id))
      after
        Repo.delete!(Scope.user(scope))
      end
    end)
  end

  defp race(operations) do
    parent = self()

    tasks =
      for operation <- operations do
        Task.async(fn -> run_operation(parent, operation) end)
      end

    Enum.each(tasks, fn _ -> assert_receive {:ready, _}, 1_000 end)
    Enum.each(tasks, &send(&1.pid, :go))
    Enum.map(tasks, &Task.await(&1, 5_000))
  end

  defp run_operation(parent, operation) do
    Sandbox.unboxed_run(Repo, fn ->
      send(parent, {:ready, self()})

      receive do
        :go -> operation.()
      after
        1_000 -> raise "customer feedback race barrier timed out"
      end
    end)
  end
end
