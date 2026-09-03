defmodule FrontmanServer.Tasks.ToolResultConcurrencyTest do
  use ExUnit.Case, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Repo
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.MCP, as: MCPTool
  alias ModelContextProtocol, as: MCP

  test "two tasks with the same tool call id receive only their own result" do
    Sandbox.unboxed_run(Repo, fn ->
      scope = user_scope_fixture()

      try do
        shared_tool_call_id = "call_shared_#{System.unique_integer([:positive])}"
        first_task_id = task_fixture(scope).id
        second_task_id = task_fixture(scope).id
        first_turn_number = start_turn_fixture(scope, first_task_id)
        second_turn_number = start_turn_fixture(scope, second_task_id)

        first_executor =
          start_executor(scope, first_task_id, first_turn_number, shared_tool_call_id)

        second_executor =
          start_executor(scope, second_task_id, second_turn_number, shared_tool_call_id)

        assert_tool_executor_registered(first_task_id, shared_tool_call_id)
        assert_tool_executor_registered(second_task_id, shared_tool_call_id)

        assert {:ok, _interaction, :notified} =
                 resolve(
                   scope,
                   first_task_id,
                   first_turn_number,
                   "first task result",
                   shared_tool_call_id
                 )

        assert {:ok, _interaction, :notified} =
                 resolve(
                   scope,
                   second_task_id,
                   second_turn_number,
                   "second task result",
                   shared_tool_call_id
                 )

        assert {:ok, [%SwarmAi.ToolResult{content: [%{text: "first task result"}]}]} =
                 Task.await(first_executor, 1_000)

        assert {:ok, [%SwarmAi.ToolResult{content: [%{text: "second task result"}]}]} =
                 Task.await(second_executor, 1_000)
      after
        Repo.delete!(Scope.user(scope))
      end
    end)
  end

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

        Registry.register(FrontmanServer.ProcessRegistry, {:tool_call, task_id, "call_dedup"}, %{
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

  defp start_executor(scope, task_id, turn_number, tool_call_id) do
    Task.async(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        ToolExecutor.execute(scope, %{
          task_id: task_id,
          turn_number: turn_number,
          tool_calls: [%SwarmAi.ToolCall{id: tool_call_id, name: "some_tool", arguments: "{}"}],
          task_supervisor: SwarmAi.Runtime.task_supervisor_name(FrontmanServer.AgentRuntime),
          backend_tool_modules: [],
          mcp_tool_defs: [mcp_tool_def()],
          execution_mode: :serial
        })
      end)
    end)
  end

  defp mcp_tool_def do
    %MCPTool{
      name: "some_tool",
      description: "Some client tool",
      input_schema: %{},
      timeout_ms: 1_000,
      on_timeout: :error
    }
  end

  defp assert_tool_executor_registered(task_id, tool_call_id) do
    assert eventually(fn ->
             Registry.lookup(FrontmanServer.ProcessRegistry, {:tool_call, task_id, tool_call_id})
           end) == [{:registered}]
  end

  defp eventually(fun), do: eventually(fun, 50)

  defp eventually(fun, attempts) when attempts > 0 do
    case fun.() do
      [] ->
        Process.sleep(10)
        eventually(fun, attempts - 1)

      [_entry] ->
        [{:registered}]
    end
  end

  defp eventually(_fun, 0), do: []

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
