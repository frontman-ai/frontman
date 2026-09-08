defmodule FrontmanServer.Tasks.Execution.ToolExecutorTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend
  alias FrontmanServer.Tools.MCP
  alias SwarmAi.Message.ContentPart

  defmodule FiniteTool do
    @behaviour Backend

    def name, do: "finite_tool"
    def description, do: "A finite backend operation"
    def access, do: :read
    def parameter_schema, do: %{"type" => "object", "properties" => %{}}
    def timeout_ms, do: 30_000
    def execute(%{"invalid" => true}, _context), do: %{"unexpected" => "shape"}
    def execute(_args, _context), do: ModelContextProtocol.tool_result_text("done")
  end

  setup do
    scope = user_scope_fixture()
    task_id = task_with_active_turn_fixture(scope).id
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))
    {:ok, scope: scope, task_id: task_id, turn_number: latest_turn_number(task_id)}
  end

  defp tool_results(task, tool_call_id) do
    Enum.filter(Tasks.interactions(task), fn
      %Interaction.ToolResult{tool_call_id: ^tool_call_id} -> true
      _ -> false
    end)
  end

  describe "canonical backend results" do
    @tag :capture_log
    test "completion and timeout return the persisted winner in either ordering", context do
      %{scope: scope, task_id: task_id, turn_number: turn_number} = context

      for first <- [:completion, :timeout] do
        tc = %SwarmAi.ToolCall{id: "race_#{first}", name: FiniteTool.name(), arguments: "{}"}

        complete = fn ->
          ToolExecutor.run_backend_tool(scope, FiniteTool, task_id, turn_number, tc)
        end

        timeout = fn -> ToolExecutor.handle_error(scope, task_id, turn_number, :timeout, tc) end

        {winner, loser} =
          case first do
            :completion -> {complete.(), timeout.()}
            :timeout -> {timeout.(), complete.()}
          end

        assert winner == loser
        assert winner.is_error == (first == :timeout)
        {:ok, task} = Tasks.get_task_with_history(scope, task_id)
        assert [stored] = tool_results(task, tc.id)
        assert stored.is_error == winner.is_error
        assert ModelContextProtocol.extract_content_text(stored.result) == hd(winner.content).text
      end
    end
  end

  @tag :capture_log
  test "a malformed backend return becomes a canonical error", context do
    %{scope: scope, task_id: task_id, turn_number: turn_number} = context

    call = %SwarmAi.ToolCall{
      id: "malformed_result",
      name: FiniteTool.name(),
      arguments: ~s({"invalid":true})
    }

    assert %SwarmAi.ToolResult{is_error: true, content: [%{text: "Invalid tool result"}]} =
             ToolExecutor.run_backend_tool(scope, FiniteTool, task_id, turn_number, call)

    {:ok, task} = Tasks.get_task_with_history(scope, task_id)

    assert [
             %Interaction.ToolResult{
               is_error: true,
               result: %{"content" => [%{"text" => "Invalid tool result"}]}
             }
           ] = tool_results(task, call.id)
  end

  test "Sync DOWN after a committed success returns that same success", context do
    %{scope: scope, task_id: task_id, turn_number: turn_number} = context
    call = %SwarmAi.ToolCall{id: "committed_then_down", name: "finite_tool", arguments: "{}"}

    execution = %SwarmAi.ToolExecution.Sync{
      tool_call: call,
      timeout_ms: 1_000,
      run: {__MODULE__, :persist_then_exit, [scope, task_id, turn_number]},
      on_error: {ToolExecutor, :handle_error, [scope, task_id, turn_number]}
    }

    assert {:ok, [%SwarmAi.ToolResult{is_error: false, content: [%{text: "committed"}]}]} =
             SwarmAi.ParallelExecutor.run(
               [execution],
               SwarmAi.Runtime.task_supervisor_name(FrontmanServer.AgentRuntime)
             )

    {:ok, task} = Tasks.get_task_with_history(scope, task_id)

    assert [
             %Interaction.ToolResult{
               is_error: false,
               result: %{"content" => [%{"text" => "committed"}]}
             }
           ] = tool_results(task, call.id)
  end

  def persist_then_exit(scope, task_id, turn_number, call) do
    {:ok, _, _} =
      Tasks.resolve_tool_request(
        scope,
        task_id,
        call,
        ModelContextProtocol.tool_result_text("committed"),
        turn_number: turn_number
      )

    Process.exit(self(), :kill)
  end

  describe "execute/2" do
    test "runs available and unavailable tools in serial and parallel", context do
      %{scope: scope, task_id: task_id, turn_number: turn_number} = context

      for mode <- [:serial, :parallel] do
        available = %SwarmAi.ToolCall{
          id: "available_#{mode}",
          name: FiniteTool.name(),
          arguments: "{}"
        }

        unavailable = %SwarmAi.ToolCall{
          id: "unavailable_#{mode}",
          name: "filtered_tool",
          arguments: "{}"
        }

        assert {:ok, results} =
                 ToolExecutor.execute(scope, %{
                   task_id: task_id,
                   turn_number: turn_number,
                   tool_calls: [available, unavailable],
                   task_supervisor:
                     SwarmAi.Runtime.task_supervisor_name(FrontmanServer.AgentRuntime),
                   backend_tool_modules: [FiniteTool],
                   mcp_tool_defs: [],
                   execution_mode: mode
                 })

        assert [
                 %SwarmAi.ToolResult{is_error: false, content: [%ContentPart{text: "done"}]},
                 %SwarmAi.ToolResult{is_error: true, content: [%ContentPart{text: message}]}
               ] = results

        assert message =~ "filtered_tool"
        assert message =~ "unavailable"
        {:ok, task} = Tasks.get_task_with_history(scope, task_id)
        assert [%Interaction.ToolResult{is_error: false}] = tool_results(task, available.id)
        assert [%Interaction.ToolResult{is_error: true}] = tool_results(task, unavailable.id)
        refute Enum.any?(Tasks.interactions(task), &match?(%Interaction.ToolCall{}, &1))
      end
    end

    test "registers before publishing and rejects a duplicate waiter", context do
      %{scope: scope, task_id: task_id, turn_number: turn_number} = context
      tc = %SwarmAi.ToolCall{id: "collision", name: "approval", arguments: "{}"}
      assert :ok = ToolExecutor.start_mcp_tool(scope, task_id, turn_number, :interactive, tc)
      assert_receive {:interaction, %{data: %Interaction.ToolCall{execution_mode: :interactive}}}

      assert [{_, %{caller_pid: caller}}] =
               Registry.lookup(FrontmanServer.ProcessRegistry, {:tool_call, task_id, tc.id})

      assert caller == self()

      assert_raise RuntimeError, ~r/Duplicate MCP tool executor registration/, fn ->
        ToolExecutor.start_mcp_tool(scope, task_id, turn_number, :interactive, tc)
      end
    end

    test "rejects a filtered backend even when an MCP tool has the same name", context do
      %{scope: scope, task_id: task_id, turn_number: turn_number} = context
      tool = MCP.from_map(%{"name" => "todo_write"})
      tc = %SwarmAi.ToolCall{id: "collision_backend", name: "todo_write", arguments: "{}"}

      assert {:ok, [%SwarmAi.ToolResult{is_error: true}]} =
               ToolExecutor.execute(scope, %{
                 task_id: task_id,
                 turn_number: turn_number,
                 tool_calls: [tc],
                 task_supervisor:
                   SwarmAi.Runtime.task_supervisor_name(FrontmanServer.AgentRuntime),
                 backend_tool_modules: [],
                 mcp_tool_defs: [tool],
                 execution_mode: :serial
               })

      {:ok, task} = Tasks.get_task_with_history(scope, task_id)
      refute Enum.any?(Tasks.interactions(task), &match?(%Interaction.ToolCall{}, &1))
      assert [%Interaction.ToolResult{is_error: true}] = tool_results(task, tc.id)
    end
  end
end
