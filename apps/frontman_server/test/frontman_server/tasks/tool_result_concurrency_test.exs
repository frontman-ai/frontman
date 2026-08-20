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

        Registry.register(
          FrontmanServer.ToolCallRegistry,
          {:tool_call, task_id, "call_dedup"},
          %{
            caller_pid: self()
          }
        )

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

  test "identical tool call ids route only to their task executors" do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()

      try do
        first_task = task_fixture(scope)
        second_task = task_fixture(scope)
        first_turn = start_turn_fixture(scope, first_task.id)
        second_turn = start_turn_fixture(scope, second_task.id)
        tool_call_id = "shared-call"

        assert {:ok, _owner} = register_receiver(first_task.id, tool_call_id, :first)
        assert {:ok, _owner} = register_receiver(second_task.id, tool_call_id, :second)

        resolvers = [
          Task.async(fn ->
            resolve(scope, first_task.id, first_turn, "first result", tool_call_id)
          end),
          Task.async(fn ->
            resolve(scope, second_task.id, second_turn, "second result", tool_call_id)
          end)
        ]

        assert Enum.all?(resolvers, fn resolver ->
                 match?({:ok, _interaction, :notified}, Task.await(resolver, 1_000))
               end)

        assert_receive {:first, {:tool_result, ^tool_call_id, first_result, false}}
        assert_receive {:second, {:tool_result, ^tool_call_id, second_result, false}}
        assert [%{text: "first result"}] = first_result
        assert [%{text: "second result"}] = second_result
        refute_receive {:first, {:tool_result, ^tool_call_id, [%{text: "second result"}], false}}
        refute_receive {:second, {:tool_result, ^tool_call_id, [%{text: "first result"}], false}}
      after
        Repo.delete!(Scope.user(scope))
      end
    end)
  end

  defp register_receiver(task_id, tool_call_id, label) do
    parent = self()

    Registry.register(
      FrontmanServer.ToolCallRegistry,
      {:tool_call, task_id, tool_call_id},
      %{caller_pid: spawn_link(fn -> forward_tool_result(parent, label) end)}
    )
  end

  defp forward_tool_result(parent, label) do
    receive do
      {:tool_result, _tool_call_id, _content, _is_error} = result ->
        send(parent, {label, result})
    after
      1_000 -> raise "timed out waiting for tool result"
    end
  end

  defp resolve(scope, task_id, turn_number, result, tool_call_id \\ "call_dedup") do
    Tasks.resolve_tool_request(
      scope,
      task_id,
      %{id: tool_call_id, name: "some_tool"},
      MCP.tool_result_text(result),
      turn_number: turn_number
    )
  end
end
