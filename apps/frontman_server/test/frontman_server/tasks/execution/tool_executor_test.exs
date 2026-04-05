defmodule FrontmanServer.Tasks.Execution.ToolExecutorTest do
  @moduledoc """
  Tests for ToolExecutor public API: make_executor/3, run_backend_tool/5,
  start_mcp_tool/3, and handle_timeout/5.
  """

  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools.Backend

  # --- Fake backend tools ---

  # A backend tool that invokes context.tool_executor to simulate sub-agent use.
  defmodule SubAgentTool do
    @behaviour Backend

    def name, do: "sub_agent_tool"
    def description, do: "Invokes context.tool_executor"
    def parameter_schema, do: %{"type" => "object", "properties" => %{}}
    def timeout_ms, do: 30_000
    def on_timeout, do: :error

    def execute(_args, context) do
      _results = context.tool_executor.([])
      {:ok, "executor is callable"}
    end
  end

  # A backend tool that declares on_timeout: :pause_agent.
  defmodule PauseOnTimeoutTool do
    @behaviour Backend

    def name, do: "pause_on_timeout_tool"
    def description, do: "Declares on_timeout: :pause_agent"
    def parameter_schema, do: %{"type" => "object", "properties" => %{}}
    def timeout_ms, do: 30_000
    def on_timeout, do: :pause_agent

    def execute(_args, _context), do: {:ok, "done"}
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
    {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

    llm_opts = [api_key: "test-key", model: "openrouter:anthropic/claude-sonnet-4-20250514"]

    {:ok, scope: scope, task_id: task_id, llm_opts: llm_opts}
  end

  describe "run_backend_tool/5 — sub-agent spawning" do
    @tag :capture_log
    test "backend tool can call context.tool_executor without crashing", %{
      scope: scope,
      task_id: task_id,
      llm_opts: llm_opts
    } do
      exec_opts = %{
        backend_tool_modules: [SubAgentTool],
        backend_module_map: %{SubAgentTool.name() => SubAgentTool},
        mcp_tools: [],
        mcp_tool_defs: [],
        llm_opts: llm_opts
      }

      tool_call = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: SubAgentTool.name(),
        arguments: "{}"
      }

      result = ToolExecutor.run_backend_tool(scope, SubAgentTool, task_id, exec_opts, tool_call)

      # SubAgentTool calls context.tool_executor.([]) and returns {:ok, "executor is callable"}.
      assert %SwarmAi.ToolResult{is_error: false} = result
    end
  end

  describe "start_mcp_tool/3 — MCP tool routing" do
    @tag :capture_log
    test "registers caller's pid in ToolCallRegistry before returning", %{
      scope: scope,
      task_id: task_id
    } do
      tool_call_id = "tc_mcp_#{System.unique_integer([:positive])}"

      tool_call = %SwarmAi.ToolCall{
        id: tool_call_id,
        name: "some_mcp_tool",
        arguments: "{}"
      }

      # start_mcp_tool is meant to be called in PE's own process (self() = PE).
      # Here, test process acts as PE.
      ToolExecutor.start_mcp_tool(scope, task_id, tool_call)

      # Verify registry registration with test process pid.
      assert [{test_pid, _}] =
               Registry.lookup(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})

      assert test_pid == self()

      # Verify tool call interaction was published so the client can execute it.
      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_calls =
        Enum.filter(task.interactions, fn
          %Tasks.Interaction.ToolCall{tool_call_id: ^tool_call_id} -> true
          _ -> false
        end)

      assert length(tool_calls) == 1,
             "start_mcp_tool/3 did not publish ToolCall interaction"
    end
  end

  describe "handle_timeout/5 — :error policy" do
    @tag :capture_log
    test "persists error ToolResult and is a no-op for :triggered reason", %{
      scope: scope,
      task_id: task_id
    } do
      tc = %SwarmAi.ToolCall{id: "tc-to-1", name: "pause_on_timeout_tool", arguments: "{}"}
      ToolExecutor.handle_timeout(scope, task_id, :error, tc, :triggered)

      {:ok, task} = Tasks.get_task(scope, task_id)

      result =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: "tc-to-1"} -> true
          _ -> false
        end)

      assert result != nil
      assert result.is_error == true
      assert result.result =~ "timed out"
    end

    @tag :capture_log
    test "persists error ToolResult for :cancelled reason", %{
      scope: scope,
      task_id: task_id
    } do
      tc = %SwarmAi.ToolCall{id: "tc-to-2", name: "some_tool", arguments: "{}"}
      ToolExecutor.handle_timeout(scope, task_id, :error, tc, :cancelled)

      {:ok, task} = Tasks.get_task(scope, task_id)

      result =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: "tc-to-2"} -> true
          _ -> false
        end)

      assert result != nil
      assert result.is_error == true
    end
  end

  describe "handle_timeout/5 — :pause_agent policy" do
    @tag :capture_log
    test "handle_timeout(:triggered) is a no-op for :pause_agent — SwarmDispatcher owns persistence",
         %{scope: scope, task_id: task_id} do
      tc = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: PauseOnTimeoutTool.name(),
        arguments: "{}"
      }

      ToolExecutor.handle_timeout(scope, task_id, :pause_agent, tc, :triggered)

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_results =
        Enum.filter(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: tc_id} -> tc_id == tc.id
          _ -> false
        end)

      assert tool_results == [],
             "Expected no ToolResult for :pause_agent/:triggered, got #{length(tool_results)}"
    end

    @tag :capture_log
    test "handle_timeout(:cancelled) persists a ToolResult for sibling tool", %{
      scope: scope,
      task_id: task_id
    } do
      tc = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: PauseOnTimeoutTool.name(),
        arguments: "{}"
      }

      ToolExecutor.handle_timeout(scope, task_id, :pause_agent, tc, :cancelled)

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_results =
        Enum.filter(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: tc_id} -> tc_id == tc.id
          _ -> false
        end)

      assert length(tool_results) == 1,
             "Expected a ToolResult for :pause_agent/:cancelled, got #{length(tool_results)}"
    end
  end

  describe "make_executor/3 — returns single function" do
    test "returns a function, not a tuple", %{scope: scope, task_id: task_id, llm_opts: llm_opts} do
      result =
        ToolExecutor.make_executor(scope, task_id,
          backend_tool_modules: [SubAgentTool],
          mcp_tools: [],
          mcp_tool_defs: [],
          llm_opts: llm_opts
        )

      assert is_function(result, 1)
    end

    test "executor returns ToolExecution.Sync for backend tools", %{
      scope: scope,
      task_id: task_id,
      llm_opts: llm_opts
    } do
      executor =
        ToolExecutor.make_executor(scope, task_id,
          backend_tool_modules: [PauseOnTimeoutTool],
          mcp_tools: [],
          mcp_tool_defs: [],
          llm_opts: llm_opts
        )

      tc = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: PauseOnTimeoutTool.name(),
        arguments: "{}"
      }

      [execution] = executor.([tc])

      assert %SwarmAi.ToolExecution.Sync{
               on_timeout_policy: :pause_agent,
               on_timeout: {ToolExecutor, :handle_timeout, [^scope, ^task_id, :pause_agent]}
             } = execution
    end

    test "executor returns ToolExecution.Await for MCP tools", %{
      scope: scope,
      task_id: task_id,
      llm_opts: llm_opts
    } do
      pause_mcp_def = %FrontmanServer.Tools.MCP{
        name: "some_mcp_tool",
        description: "test",
        input_schema: %{},
        on_timeout: :pause_agent,
        timeout_ms: 60_000
      }

      executor =
        ToolExecutor.make_executor(scope, task_id,
          backend_tool_modules: [],
          mcp_tools: [],
          mcp_tool_defs: [pause_mcp_def],
          llm_opts: llm_opts
        )

      tc = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: "some_mcp_tool",
        arguments: "{}"
      }

      [execution] = executor.([tc])

      assert %SwarmAi.ToolExecution.Await{
               on_timeout_policy: :pause_agent,
               message_key: tc_id,
               on_timeout: {ToolExecutor, :handle_timeout, [^scope, ^task_id, :pause_agent]}
             } = execution

      assert tc_id == tc.id
    end
  end
end
