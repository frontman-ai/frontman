defmodule FrontmanServer.Tasks.ToolResultConcurrencyTest do
  use ExUnit.Case, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias ModelContextProtocol, as: MCP

  test "concurrent tool results resolve to one canonical interaction" do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()

      try do
        task_id = task_fixture(scope).id
        turn_number = start_turn_fixture(scope, task_id)
        parent = self()

        tasks =
          for result <- ["result1", "result2"] do
            Task.async(fn ->
              Sandbox.unboxed_run(Repo, fn ->
                send(parent, {:ready, self()})

                receive do
                  :resolve -> resolve(scope, task_id, turn_number, result)
                after
                  1_000 -> raise "timed out waiting to resolve tool result"
                end
              end)
            end)
          end

        assert_receive {:ready, _task_pid}, 1_000
        assert_receive {:ready, _task_pid}, 1_000
        Enum.each(tasks, &send(&1.pid, :resolve))

        results = Enum.map(tasks, &Task.await(&1, 1_000))

        assert Enum.all?(results, &match?({:ok, _interaction, :no_executor}, &1))

        [{:ok, canonical, :no_executor}, {:ok, canonical, :no_executor}] = results

        Registry.register(FrontmanServer.ProcessRegistry, {:tool_call, "call_dedup"}, %{
          caller_pid: self()
        })

        assert {:ok, ^canonical, :notified} =
                 resolve(scope, task_id, turn_number, "late result")

        assert %{"content" => [%{"text" => canonical_text}]} = canonical.result
        assert_receive {:tool_result, "call_dedup", [%{text: ^canonical_text}], false}

        {:ok, task} = Tasks.get_task(scope, task_id)

        assert [_result] =
                 Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
      after
        Repo.delete!(Scope.user(scope))
      end
    end)
  end

  defp resolve(scope, task_id, turn_number, result) do
    Tasks.resolve_tool_request(
      scope,
      task_id,
      %{id: "call_dedup", name: "some_tool"},
      MCP.tool_result_text(result),
      turn_number: turn_number
    )
  end
end
