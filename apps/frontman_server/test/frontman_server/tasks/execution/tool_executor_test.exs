defmodule FrontmanServer.Tasks.Execution.ToolExecutorTest do
  @moduledoc """
  Focused tests for ToolExecutor callback shaping and result enrichment.
  """

  use ExUnit.Case, async: false

  import FrontmanServer.InteractionCase.Helpers, only: [assert_receive_interaction: 3]
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.TaskSchema
  alias FrontmanServer.Tools.Backend
  alias SwarmAi.Message.ContentPart

  # --- Fake backend tools ---

  # A backend tool that declares on_timeout: :pause_agent.
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
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "tool_executor_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    task_id = Ecto.UUID.generate()
    {:ok, %TaskSchema{id: ^task_id}} = Tasks.create_task(scope, task_id, "nextjs")
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))

    {:ok, _message} =
      user_message_fixture(scope, task_id, [%{"type" => "text", "text" => "test turn"}])

    {:ok, scope: scope, task_id: task_id, turn_number: latest_turn_number(task_id)}
  end

  defp tool_results(task, tool_call_id) do
    Enum.filter(task.interactions, fn
      %Interaction.ToolResult{tool_call_id: ^tool_call_id} -> true
      _ -> false
    end)
  end

  describe "start_mcp_tool/3" do
    test "persists MCP tool call interactions", %{
      scope: scope,
      task_id: task_id,
      turn_number: turn_number
    } do
      tool_call = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: "take_screenshot",
        arguments: ~s({"selector":"#main"})
      }

      assert :ok = ToolExecutor.start_mcp_tool(scope, task_id, turn_number, tool_call)

      {:ok, task} = Tasks.get_task(scope, task_id)

      assert %Interaction.ToolCall{
               tool_call_id: tool_call_id,
               tool_name: "take_screenshot",
               arguments: %{"selector" => "#main"}
             } = Enum.find(task.interactions, &match?(%Interaction.ToolCall{}, &1))

      assert tool_call_id == tool_call.id
    end
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

      {:ok, task} = Tasks.get_task(scope, task_id)
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

      {:ok, task} = Tasks.get_task(scope, task_id)
      assert [%Interaction.ToolResult{is_error: true}] = tool_results(task, tc.id)
    end
  end

  describe "execute/2" do
    test "runs backend tools and returns ToolResult structs", %{
      scope: scope,
      task_id: task_id,
      turn_number: turn_number
    } do
      tc = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: PauseOnTimeoutTool.name(),
        arguments: "{}"
      }

      assert {:ok, [%SwarmAi.ToolResult{id: tool_call_id, is_error: false} = result]} =
               ToolExecutor.execute(scope, %{
                 task_id: task_id,
                 turn_number: turn_number,
                 tool_calls: [tc],
                 task_supervisor: SwarmAi.task_supervisor_name(FrontmanServer.AgentRuntime),
                 backend_tool_modules: [PauseOnTimeoutTool],
                 mcp_tool_defs: [],
                 execution_mode: :parallel
               })

      assert tool_call_id == tc.id
      assert [%ContentPart{type: :text, text: "done"}] = result.content

      {:ok, task} = Tasks.get_task(scope, task_id)
      assert [%Interaction.ToolResult{is_error: false}] = tool_results(task, tc.id)
    end

    test "runs MCP tools through await result routing", %{
      scope: scope,
      task_id: task_id,
      turn_number: turn_number
    } do
      pause_mcp_def = %FrontmanServer.Tools.MCP{
        name: "some_mcp_tool",
        description: "test",
        input_schema: %{},
        on_timeout: :pause_agent,
        timeout_ms: 60_000
      }

      tc = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: "some_mcp_tool",
        arguments: "{}"
      }

      task =
        Task.async(fn ->
          ToolExecutor.execute(scope, %{
            task_id: task_id,
            turn_number: turn_number,
            tool_calls: [tc],
            task_supervisor: SwarmAi.task_supervisor_name(FrontmanServer.AgentRuntime),
            backend_tool_modules: [],
            mcp_tool_defs: [pause_mcp_def],
            execution_mode: :serial
          })
        end)

      assert_receive_interaction(
        %Interaction.ToolCall{tool_call_id: tool_call_id},
        _turn_number,
        500
      )

      assert tool_call_id == tc.id

      [{_pid, %{caller_pid: caller}}] =
        Registry.lookup(FrontmanServer.ToolCallRegistry, {:tool_call, tc.id})

      send(
        caller,
        {:tool_result, tc.id, [ContentPart.text("mcp done")], false}
      )

      assert {:ok, [%SwarmAi.ToolResult{id: tool_call_id, is_error: false} = result]} =
               Task.await(task, 1_000)

      assert tool_call_id == tc.id
      assert [%ContentPart{type: :text, text: "mcp done"}] = result.content
    end
  end
end
