defmodule SwarmAi.TimeoutOwnershipTest do
  @moduledoc """
  Verifies the timeout ownership contract (#760):
  ParallelExecutor is the single timeout authority for all tool types.

  These tests demonstrate:
  - PE's deadline kills blocked `receive` tasks (no internal after needed)
  - Registry auto-cleans up when PE kills a process
  - Per-tool timeout isolation in mixed batches
  - No double-timeout race conditions
  """

  use ExUnit.Case, async: true

  alias SwarmAi.{ParallelExecutor, ToolCall, ToolExecution, ToolResult}
  alias SwarmAi.Message.ContentPart

  # --- Test MFA callbacks ---

  @doc """
  Simulates an MCP tool that blocks in a bare `receive` with NO `after` clause,
  exactly like the fixed AgentStrategy.execute_mcp_tool after #760.
  PE must be the one to kill this process on deadline.
  """
  def run_blocking_receive(_tool_call) do
    # Block forever — PE's deadline must terminate this task
    receive do
      :never -> :ok
    end
  end

  @doc """
  Simulates a tool that completes quickly.
  """
  def run_instant(content, tool_call) do
    ToolResult.make(tool_call.id, content, false)
  end

  @doc """
  Simulates a tool that takes a specific amount of time.
  """
  def run_slow(delay_ms, content, tool_call) do
    Process.sleep(delay_ms)
    ToolResult.make(tool_call.id, content, false)
  end

  def noop_timeout(_tool_call, _reason), do: :ok

  def record_timeout(test_pid, tool_call, reason) do
    send(test_pid, {:timeout_called, tool_call.id, reason})
  end

  # --- Helpers ---

  defp make_tc(id, name), do: %ToolCall{id: id, name: name, arguments: "{}"}

  defp start_sup do
    {:ok, sup} = Task.Supervisor.start_link()
    sup
  end

  defp content_text(%ToolResult{content: content}), do: ContentPart.extract_text(content)

  # --- Tests ---

  describe "PE kills blocked receive on deadline (#760)" do
    test "Sync tool blocking in bare receive is terminated by PE deadline" do
      sup = start_sup()
      tc = make_tc("block1", "mcp_tool")

      exec = %ToolExecution.Sync{
        tool_call: tc,
        timeout_ms: 50,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_blocking_receive, []},
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      # Should return within ~50ms, not hang forever
      {:ok, [result]} = ParallelExecutor.run([exec], sup)
      assert result.is_error == true
      assert content_text(result) =~ "timed out"
    end

    test "on_timeout callback fires for blocked-receive tool" do
      sup = start_sup()
      test_pid = self()
      tc = make_tc("block1", "mcp_tool")

      exec = %ToolExecution.Sync{
        tool_call: tc,
        timeout_ms: 50,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_blocking_receive, []},
        on_timeout: {__MODULE__, :record_timeout, [test_pid]}
      }

      ParallelExecutor.run([exec], sup)
      assert_receive {:timeout_called, "block1", :triggered}, 1_000
    end
  end

  describe "per-tool timeout isolation (#760)" do
    test "fast-timeout tool fails independently while slow-timeout tool succeeds" do
      sup = start_sup()
      fast_tc = make_tc("fast1", "fast_tool")
      slow_tc = make_tc("slow1", "slow_tool")

      # fast_tool: blocks forever, 30ms deadline → should timeout
      fast_exec = %ToolExecution.Sync{
        tool_call: fast_tc,
        timeout_ms: 30,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_blocking_receive, []},
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      # slow_tool: takes 10ms to complete, 5000ms deadline → should succeed
      slow_exec = %ToolExecution.Sync{
        tool_call: slow_tc,
        timeout_ms: 5_000,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_slow, [10, "slow_done"]},
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      {:ok, [fast_result, slow_result]} = ParallelExecutor.run([fast_exec, slow_exec], sup)

      # fast_tool timed out
      assert fast_result.is_error == true
      assert content_text(fast_result) =~ "timed out"

      # slow_tool succeeded — fast_tool's timeout didn't affect it
      assert slow_result.is_error == false
      assert content_text(slow_result) == "slow_done"
    end

    test "different tools have different deadlines" do
      sup = start_sup()
      test_pid = self()
      tc1 = make_tc("id1", "tool_a")
      tc2 = make_tc("id2", "tool_b")

      # tool_a: 30ms deadline
      exec1 = %ToolExecution.Sync{
        tool_call: tc1,
        timeout_ms: 30,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_blocking_receive, []},
        on_timeout: {__MODULE__, :record_timeout, [test_pid]}
      }

      # tool_b: 100ms deadline
      exec2 = %ToolExecution.Sync{
        tool_call: tc2,
        timeout_ms: 100,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_blocking_receive, []},
        on_timeout: {__MODULE__, :record_timeout, [test_pid]}
      }

      {:ok, [r1, r2]} = ParallelExecutor.run([exec1, exec2], sup)

      # Both timed out, but tool_a should have timed out first
      assert r1.is_error == true
      assert r2.is_error == true

      # Collect timeout callbacks — verify both fired
      calls =
        for _ <- 1..2 do
          assert_receive {:timeout_called, id, :triggered}, 1_000
          id
        end

      assert "id1" in calls
      assert "id2" in calls
    end
  end

  describe "Registry auto-cleanup on process kill (#760)" do
    test "Registry key is cleaned up when PE kills the task" do
      # Set up a dedicated Registry for this test
      reg_name = :"test_tool_reg_#{System.unique_integer([:positive])}"
      {:ok, _} = Registry.start_link(keys: :unique, name: reg_name)

      sup = start_sup()
      tc = make_tc("reg_test", "mcp_tool")

      # Tool that registers in a Registry, then blocks forever
      exec = %ToolExecution.Sync{
        tool_call: tc,
        timeout_ms: 50,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_register_and_block, [reg_name, tc.id]},
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      {:ok, [result]} = ParallelExecutor.run([exec], sup)
      assert result.is_error == true

      # Give the system a moment to process the EXIT signal
      Process.sleep(50)

      # Registry key should be auto-cleaned because the process died
      assert Registry.lookup(reg_name, {:awaiting_result, tc.id}) == []
    end
  end

  describe "pause_agent with blocked receive (#760)" do
    test "interactive tool blocking in receive triggers :pause_agent via PE deadline" do
      sup = start_sup()
      tc = make_tc("q1", "question")

      exec = %ToolExecution.Sync{
        tool_call: tc,
        timeout_ms: 50,
        on_timeout_policy: :pause_agent,
        run: {__MODULE__, :run_blocking_receive, []},
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      assert {:halt, {:pause_agent, "q1", "question", 50}} =
               ParallelExecutor.run([exec], sup)
    end
  end

  # --- Helpers for Registry cleanup test ---

  def run_register_and_block(reg_name, tool_call_id, _tool_call) do
    Registry.register(reg_name, {:awaiting_result, tool_call_id}, %{})

    receive do
      :never -> :ok
    end
  end
end
