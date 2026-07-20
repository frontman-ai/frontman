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
          Enum.map(["result1", "result2"], fn result ->
            Task.async(fn ->
              Sandbox.unboxed_run(Repo, fn ->
                send(parent, {:ready, self()})

                receive do
                  :resolve ->
                    Tasks.resolve_tool_request(
                      scope,
                      task_id,
                      %{id: "call_dedup", name: "some_tool"},
                      MCP.tool_result_text(result),
                      false,
                      turn_number: turn_number
                    )
                after
                  1_000 -> raise "timed out waiting to resolve tool result"
                end
              end)
            end)
          end)

        task_pids =
          Enum.map(tasks, fn _task ->
            assert_receive {:ready, task_pid}, 1_000
            task_pid
          end)

        Enum.each(task_pids, &send(&1, :resolve))

        results = Enum.map(tasks, &Task.await(&1, 1_000))

        assert Enum.sort(Enum.map(results, fn {:ok, _interaction, status} -> status end)) ==
                 [:duplicate, :no_executor]

        assert 1 ==
                 results
                 |> Enum.map(fn {:ok, interaction, _status} -> interaction.id end)
                 |> Enum.uniq()
                 |> length()

        {:ok, task} = Tasks.get_task(scope, task_id)

        assert [_result] =
                 Enum.filter(Tasks.interactions(task), &match?(%Interaction.ToolResult{}, &1))
      after
        Repo.delete!(Scope.user(scope))
      end
    end)
  end
end
