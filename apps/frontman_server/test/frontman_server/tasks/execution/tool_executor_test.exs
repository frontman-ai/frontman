defmodule FrontmanServer.Tasks.Execution.ToolExecutorTest do
  @moduledoc """
  Regression tests for ToolExecutor bugs found in PR #761 review.

  Bug 1: execute_backend_tool passes the {executor_fn, on_deadline_fn} tuple
  as Backend.Context.tool_executor instead of just the executor function.
  Any backend tool that calls context.tool_executor.(...) crashes.

  Bug 2: on_deadline always defaults to :error for backend tools, ignoring the
  module's on_timeout/0 callback. A backend tool with on_timeout: :pause_agent
  incorrectly gets a ToolResult persisted by on_deadline.
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
  # Will crash with BadFunctionError if context.tool_executor is the
  # {executor_fn, on_deadline_fn} tuple instead of just the executor function.
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
  # on_deadline should be a no-op for this tool — SwarmDispatcher handles persistence.
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

  describe "execute/4 — backend tool sub-agent spawning" do
    @tag :capture_log
    test "backend tool can call context.tool_executor without crashing", %{
      scope: scope,
      task_id: task_id,
      llm_opts: llm_opts
    } do
      tool_call = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: SubAgentTool.name(),
        arguments: "{}"
      }

      result =
        ToolExecutor.execute(scope, tool_call, task_id,
          backend_tool_modules: [SubAgentTool],
          mcp_tools: [],
          mcp_tool_defs: [],
          llm_opts: llm_opts
        )

      # SubAgentTool calls context.tool_executor.([]) and returns {:ok, "executor is callable"}.
      # Bug: execute_backend_tool assigns the {fn, fn} tuple to context.tool_executor.
      # Calling the tuple crashes with BadFunctionError, which is caught and returned as
      # {:error, "..."}. After the fix this should be {:ok, _}.
      assert {:ok, _} = result
    end
  end

  describe "execute/4 — MCP tool routing" do
    @tag :capture_log
    test "registers in ToolCallRegistry before blocking so the result can be delivered", %{
      scope: scope,
      task_id: task_id,
      llm_opts: llm_opts
    } do
      tool_call_id = "tc_mcp_#{System.unique_integer([:positive])}"

      tool_call = %SwarmAi.ToolCall{
        id: tool_call_id,
        name: "some_mcp_tool",
        arguments: "{}"
      }

      # Run execute/4 in a background task — it will block in receive.
      executor_task =
        Task.async(fn ->
          ToolExecutor.execute(scope, tool_call, task_id,
            backend_tool_modules: [],
            mcp_tools: [],
            mcp_tool_defs: [],
            llm_opts: llm_opts
          )
        end)

      # Poll the registry. After the fix, execute/4 registers before blocking.
      # Without the fix, the registration never happens and await_registry returns nil.
      registered_pid = await_registry({:tool_call, tool_call_id}, 500)

      if is_nil(registered_pid) do
        Task.shutdown(executor_task, :brutal_kill)

        flunk(
          "execute/4 did not register MCP tool call in ToolCallRegistry — " <>
            "the receive block can never be unblocked"
        )
      end

      # Deliver the result to unblock the executor.
      send(registered_pid, {:tool_result, tool_call_id, "mcp result", false})
      assert {:ok, "mcp result"} = Task.await(executor_task, 1_000)

      # The tool call interaction must also be published so the client knows to execute it.
      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_calls =
        Enum.filter(task.interactions, fn
          %Tasks.Interaction.ToolCall{tool_call_id: ^tool_call_id} -> true
          _ -> false
        end)

      assert length(tool_calls) == 1,
             "execute/4 did not publish ToolCall interaction — client can never send the result"
    end
  end

  describe "make_executor/3 — on_deadline policy for backend tools" do
    @tag :capture_log
    test "on_deadline is a no-op for backend tool with on_timeout: :pause_agent", %{
      scope: scope,
      task_id: task_id,
      llm_opts: llm_opts
    } do
      {_executor, on_deadline} =
        ToolExecutor.make_executor(scope, task_id,
          backend_tool_modules: [PauseOnTimeoutTool],
          mcp_tools: [],
          mcp_tool_defs: [],
          llm_opts: llm_opts
        )

      tool_call = %SwarmAi.ToolCall{
        id: "tc_#{System.unique_integer([:positive])}",
        name: PauseOnTimeoutTool.name(),
        arguments: "{}"
      }

      on_deadline.(tool_call)

      # For on_timeout: :pause_agent, on_deadline must not persist a ToolResult.
      # SwarmDispatcher owns persistence in the pause path.
      # Bug: on_deadline falls through to :error for all backend tools, persisting
      # an error ToolResult even when on_timeout is :pause_agent.
      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_results =
        Enum.filter(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: tc_id} -> tc_id == tool_call.id
          _ -> false
        end)

      assert tool_results == [],
             "Expected no ToolResult for on_timeout: :pause_agent, got #{length(tool_results)}"
    end
  end

  # --- Helpers ---

  # Polls ToolCallRegistry until `key` is registered or `timeout_ms` elapses.
  # Returns the registered PID or nil on timeout.
  defp await_registry(key, timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_await_registry(key, deadline)
  end

  defp do_await_registry(key, deadline) do
    case Registry.lookup(FrontmanServer.ToolCallRegistry, key) do
      [{pid, _}] ->
        pid

      [] ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(5)
          do_await_registry(key, deadline)
        else
          nil
        end
    end
  end
end
