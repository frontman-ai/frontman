defmodule FrontmanServer.Tasks.Execution.ToolExecutorTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend
  alias SwarmAi.Message.ContentPart

  defmodule PauseOnTimeoutTool do
    @behaviour Backend

    def name, do: "pause_on_timeout_tool"
    def description, do: "Declares on_timeout: :pause_agent"
    def access, do: :read
    def parameter_schema, do: %{"type" => "object", "properties" => %{}}
    def timeout_ms, do: 30_000
    def on_timeout, do: :pause_agent

    def execute(_args, _context), do: ModelContextProtocol.tool_result_text("done")
  end

  setup do
    scope = user_scope_fixture()
    task_id = task_fixture(scope).id
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))
    {:ok, _message} = user_message_fixture(scope, task_id, user_content("test turn"))

    {:ok, scope: scope, task_id: task_id, turn_number: latest_turn_number(task_id)}
  end

  defp tool_results(task, tool_call_id) do
    Enum.filter(Tasks.interactions(task), fn
      %Interaction.ToolResult{tool_call_id: ^tool_call_id} -> true
      _ -> false
    end)
  end

  describe "handle_timeout/5 — cancelled tools" do
    @tag :capture_log
    test "persists error ToolResult for :error policy", %{
      scope: scope,
      task_id: task_id,
      turn_number: turn_number
    } do
      tc = %SwarmAi.ToolCall{id: "tc-to-2", name: "some_tool", arguments: "{}"}
      ToolExecutor.handle_timeout(scope, task_id, turn_number, :error, tc, :cancelled)

      {:ok, task} = Tasks.get_task_with_history(scope, task_id)
      assert [%Interaction.ToolResult{is_error: true}] = tool_results(task, tc.id)
    end

    @tag :capture_log
    test "persists ToolResult for :pause_agent policy", %{
      scope: scope,
      task_id: task_id,
      turn_number: turn_number
    } do
      tc = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: PauseOnTimeoutTool.name(),
        arguments: "{}"
      }

      ToolExecutor.handle_timeout(scope, task_id, turn_number, :pause_agent, tc, :cancelled)

      {:ok, task} = Tasks.get_task_with_history(scope, task_id)
      assert [%Interaction.ToolResult{is_error: true}] = tool_results(task, tc.id)
    end
  end

  describe "execute/2" do
    test "runs available and unavailable tools in serial and parallel", %{
      scope: scope,
      task_id: task_id,
      turn_number: turn_number
    } do
      for mode <- [:serial, :parallel] do
        suffix = Atom.to_string(mode)

        available = %SwarmAi.ToolCall{
          id: "available_#{suffix}",
          name: PauseOnTimeoutTool.name(),
          arguments: "{}"
        }

        unavailable = %SwarmAi.ToolCall{
          id: "unavailable_#{suffix}",
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
                   backend_tool_modules: [PauseOnTimeoutTool],
                   mcp_tool_defs: [],
                   execution_mode: mode
                 })

        assert %SwarmAi.ToolResult{is_error: false, content: [%ContentPart{text: "done"}]} =
                 Enum.find(results, &(&1.id == available.id))

        assert %SwarmAi.ToolResult{is_error: true, content: [%ContentPart{text: message}]} =
                 Enum.find(results, &(&1.id == unavailable.id))

        assert message =~ "filtered_tool"
        assert message =~ "unavailable"

        {:ok, task} = Tasks.get_task_with_history(scope, task_id)
        assert [%Interaction.ToolResult{is_error: false}] = tool_results(task, available.id)
        assert [%Interaction.ToolResult{is_error: true}] = tool_results(task, unavailable.id)

        refute Enum.any?(Tasks.interactions(task), fn
                 %Interaction.ToolCall{tool_call_id: id} -> id == unavailable.id
                 _interaction -> false
               end)
      end
    end

    test "raises when an MCP tool executor registration unexpectedly collides", %{
      scope: scope,
      task_id: task_id,
      turn_number: turn_number
    } do
      tc = %SwarmAi.ToolCall{
        id: "tc_collision_#{System.unique_integer([:positive])}",
        name: "some_tool",
        arguments: "{}"
      }

      assert :ok = ToolExecutor.start_mcp_tool(scope, task_id, turn_number, tc)

      assert_raise RuntimeError,
                   ~r/Duplicate MCP tool executor registration/,
                   fn -> ToolExecutor.start_mcp_tool(scope, task_id, turn_number, tc) end
    end

    test "rejects a filtered backend tool even when an MCP tool has the same name", %{
      scope: scope,
      task_id: task_id,
      turn_number: turn_number
    } do
      todo_write_mcp_def = %FrontmanServer.Tools.MCP{
        name: "todo_write",
        description: "Colliding browser tool",
        input_schema: %{},
        on_timeout: :error,
        timeout_ms: 60_000
      }

      tc = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: "todo_write",
        arguments: "{}"
      }

      assert {:ok, [%SwarmAi.ToolResult{is_error: true}]} =
               ToolExecutor.execute(scope, %{
                 task_id: task_id,
                 turn_number: turn_number,
                 tool_calls: [tc],
                 task_supervisor:
                   SwarmAi.Runtime.task_supervisor_name(FrontmanServer.AgentRuntime),
                 backend_tool_modules: [],
                 mcp_tool_defs: [todo_write_mcp_def],
                 execution_mode: :serial
               })

      {:ok, task} = Tasks.get_task_with_history(scope, task_id)

      refute Enum.any?(Tasks.interactions(task), fn
               %Interaction.ToolCall{tool_call_id: tool_call_id} -> tool_call_id == tc.id
               _interaction -> false
             end)

      assert [%Interaction.ToolResult{is_error: true}] = tool_results(task, tc.id)
    end
  end
end
