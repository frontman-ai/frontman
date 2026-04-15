defmodule SwarmAi.ParallelExecutorTest do
  use ExUnit.Case, async: true

  alias SwarmAi.{Message.ContentPart, ParallelExecutor, ToolCall, ToolExecution, ToolResult}

  # --- Test MFA callbacks ---

  # All functions called by PE via MFA must be public.

  def run_instant(content, tool_call) do
    ToolResult.make(tool_call.id, content, false)
  end

  def run_slow(delay_ms, content, tool_call) do
    Process.sleep(delay_ms)
    ToolResult.make(tool_call.id, content, false)
  end

  def run_error(content, tool_call) do
    ToolResult.make(tool_call.id, content, true)
  end

  def run_crash(_tool_call) do
    raise "boom"
  end

  def noop_timeout(_tool_call, _reason), do: :ok

  def record_timeout(test_pid, tool_call, reason) do
    send(test_pid, {:timeout_called, tool_call.id, reason})
  end

  def start_await_soon(result_content, tool_call) do
    pe_pid = self()
    key = tool_call.id

    spawn(fn ->
      Process.sleep(10)
      send(pe_pid, {:tool_result, key, result_content, false})
    end)

    :ok
  end

  # --- Helpers ---

  defp make_tc(id, name), do: %ToolCall{id: id, name: name, arguments: "{}"}

  defp sync_exec(tc, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 5_000)
    policy = Keyword.get(opts, :policy, :error)
    content = Keyword.get(opts, :content, "done:#{tc.name}")

    %ToolExecution.Sync{
      tool_call: tc,
      timeout_ms: timeout_ms,
      on_timeout_policy: policy,
      run: {__MODULE__, :run_instant, [content]},
      on_timeout: {__MODULE__, :noop_timeout, []}
    }
  end

  defp await_exec(tc, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 5_000)
    policy = Keyword.get(opts, :policy, :error)
    content = Keyword.get(opts, :content, "await:#{tc.name}")

    %ToolExecution.Await{
      tool_call: tc,
      timeout_ms: timeout_ms,
      on_timeout_policy: policy,
      start: {__MODULE__, :start_await_soon, [content]},
      message_key: tc.id,
      on_timeout: {__MODULE__, :noop_timeout, []}
    }
  end

  defp start_sup do
    {:ok, sup} = Task.Supervisor.start_link()
    sup
  end

  defp content_text(%ToolResult{content: content}), do: ContentPart.extract_text(content)

  # --- Tests ---

  describe "run/2 — Sync normal completion" do
    test "returns {:ok, results} for a single Sync tool" do
      sup = start_sup()
      tc = make_tc("id1", "t1")

      assert {:ok, [%ToolResult{id: "id1"} = r]} =
               ParallelExecutor.run([sync_exec(tc)], sup)

      assert content_text(r) == "done:t1"
    end

    test "returns results in original order for concurrent Sync tools" do
      sup = start_sup()
      slow_tc = make_tc("slow1", "slow")
      fast_tc = make_tc("fast1", "fast")

      slow = %ToolExecution.Sync{
        tool_call: slow_tc,
        timeout_ms: 5_000,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_slow, [50, "slow"]},
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      fast = sync_exec(fast_tc, content: "fast")

      {:ok, [r1, r2]} = ParallelExecutor.run([slow, fast], sup)

      assert r1.id == "slow1"
      assert r2.id == "fast1"
    end
  end

  describe "run/2 — Await normal completion" do
    test "returns {:ok, results} for a single Await tool" do
      sup = start_sup()
      tc = make_tc("id1", "mcp1")

      assert {:ok, [%ToolResult{id: "id1"} = r]} =
               ParallelExecutor.run([await_exec(tc, content: "await result")], sup)

      assert content_text(r) == "await result"
    end

    test "process_result MFA is called and its return value becomes the ToolResult" do
      sup = start_sup()
      tc = make_tc("id1", "mcp1")

      exec = %ToolExecution.Await{
        tool_call: tc,
        timeout_ms: 5_000,
        on_timeout_policy: :error,
        start: {__MODULE__, :start_await_soon, ["raw content"]},
        message_key: tc.id,
        on_timeout: {__MODULE__, :noop_timeout, []},
        process_result: {__MODULE__, :make_custom_result, []}
      }

      {:ok, [result]} = ParallelExecutor.run([exec], sup)
      assert content_text(result) == "enriched!"
    end

    test "Await error result propagates is_error flag" do
      sup = start_sup()
      tc = make_tc("id1", "mcp1")
      pe_pid = self()

      exec = %ToolExecution.Await{
        tool_call: tc,
        timeout_ms: 5_000,
        on_timeout_policy: :error,
        start: fn _tc ->
          spawn(fn -> send(pe_pid, {:tool_result, tc.id, "mcp error", true}) end)
          :ok
        end,
        message_key: tc.id,
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      # start is an anonymous fn here — use a wrapper that accepts MFA format
      # Instead use a direct helper approach
      _ = exec

      # Use a proper MFA-compatible approach via a captured pid
      exec2 = %ToolExecution.Await{
        tool_call: tc,
        timeout_ms: 5_000,
        on_timeout_policy: :error,
        start: {__MODULE__, :start_await_error, [pe_pid]},
        message_key: tc.id,
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      {:ok, [result]} = ParallelExecutor.run([exec2], sup)
      assert result.is_error == true
      assert content_text(result) == "mcp error"
    end
  end

  describe "run/2 — on_timeout: :error" do
    test "timed-out Sync tool returns error ToolResult, agent continues" do
      sup = start_sup()
      tc = make_tc("id1", "slow")

      exec = %ToolExecution.Sync{
        tool_call: tc,
        timeout_ms: 10,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_slow, [500, "too late"]},
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      {:ok, [result]} = ParallelExecutor.run([exec], sup)
      assert result.is_error == true
      assert content_text(result) =~ "timed out"
    end

    test "timed-out Await tool returns error ToolResult, agent continues" do
      sup = start_sup()
      tc = make_tc("id1", "mcp_slow")

      exec = %ToolExecution.Await{
        tool_call: tc,
        timeout_ms: 10,
        on_timeout_policy: :error,
        # Never sends a result back
        start: {__MODULE__, :start_await_never, []},
        message_key: tc.id,
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      {:ok, [result]} = ParallelExecutor.run([exec], sup)
      assert result.is_error == true
      assert content_text(result) =~ "timed out"
    end
  end

  describe "run/2 — on_timeout: :pause_agent" do
    test "Sync pause_agent timeout halts with correct reason" do
      sup = start_sup()
      tc = make_tc("id1", "interactive")

      exec = %ToolExecution.Sync{
        tool_call: tc,
        timeout_ms: 10,
        on_timeout_policy: :pause_agent,
        run: {__MODULE__, :run_slow, [500, "never"]},
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      assert {:halt, {:pause_agent, "id1", "interactive", 10}} =
               ParallelExecutor.run([exec], sup)
    end

    test "Await pause_agent timeout halts with correct reason" do
      sup = start_sup()
      tc = make_tc("id1", "mcp_interactive")

      exec = %ToolExecution.Await{
        tool_call: tc,
        timeout_ms: 10,
        on_timeout_policy: :pause_agent,
        start: {__MODULE__, :start_await_never, []},
        message_key: tc.id,
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      assert {:halt, {:pause_agent, "id1", "mcp_interactive", 10}} =
               ParallelExecutor.run([exec], sup)
    end

    test "mixed batch: one pauses, others are cancelled, returns halt" do
      sup = start_sup()
      tc1 = make_tc("id1", "interactive")
      tc2 = make_tc("id2", "normal")

      pause_exec = %ToolExecution.Sync{
        tool_call: tc1,
        timeout_ms: 20,
        on_timeout_policy: :pause_agent,
        run: {__MODULE__, :run_slow, [500, "never"]},
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      normal_exec = %ToolExecution.Sync{
        tool_call: tc2,
        timeout_ms: 5_000,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_slow, [500, "never"]},
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      assert {:halt, {:pause_agent, "id1", "interactive", 20}} =
               ParallelExecutor.run([pause_exec, normal_exec], sup)
    end

    test "two pause_agent tools with same timeout: exactly one halt returned" do
      sup = start_sup()
      tc1 = make_tc("id1", "a")
      tc2 = make_tc("id2", "b")

      make_pause = fn tc ->
        %ToolExecution.Sync{
          tool_call: tc,
          timeout_ms: 10,
          on_timeout_policy: :pause_agent,
          run: {__MODULE__, :run_slow, [500, "never"]},
          on_timeout: {__MODULE__, :noop_timeout, []}
        }
      end

      result = ParallelExecutor.run([make_pause.(tc1), make_pause.(tc2)], sup)
      assert {:halt, {:pause_agent, _id, _name, 10}} = result
    end
  end

  describe "run/2 — Sync task crash" do
    test "crashing Sync tool produces error ToolResult, agent continues" do
      sup = start_sup()
      tc = make_tc("id1", "crasher")

      exec = %ToolExecution.Sync{
        tool_call: tc,
        timeout_ms: 5_000,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_crash, []},
        on_timeout: {__MODULE__, :noop_timeout, []}
      }

      {:ok, [result]} = ParallelExecutor.run([exec], sup)
      assert result.is_error == true
      assert content_text(result) =~ "crashed"
    end
  end

  describe "run/2 — on_timeout callback" do
    test "calls on_timeout(:triggered) before terminating a timed-out :error Sync tool" do
      sup = start_sup()
      test_pid = self()
      tc = make_tc("id1", "slow")

      exec = %ToolExecution.Sync{
        tool_call: tc,
        timeout_ms: 10,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_slow, [500, "too late"]},
        on_timeout: {__MODULE__, :record_timeout, [test_pid]}
      }

      ParallelExecutor.run([exec], sup)
      assert_receive {:timeout_called, "id1", :triggered}, 1_000
    end

    test "calls on_timeout(:triggered) for the pausing tool and on_timeout(:cancelled) for siblings" do
      sup = start_sup()
      test_pid = self()
      tc1 = make_tc("id1", "interactive")
      tc2 = make_tc("id2", "normal")

      pause_exec = %ToolExecution.Sync{
        tool_call: tc1,
        timeout_ms: 10,
        on_timeout_policy: :pause_agent,
        run: {__MODULE__, :run_slow, [500, "never"]},
        on_timeout: {__MODULE__, :record_timeout, [test_pid]}
      }

      normal_exec = %ToolExecution.Sync{
        tool_call: tc2,
        timeout_ms: 5_000,
        on_timeout_policy: :error,
        run: {__MODULE__, :run_slow, [500, "never"]},
        on_timeout: {__MODULE__, :record_timeout, [test_pid]}
      }

      ParallelExecutor.run([pause_exec, normal_exec], sup)

      calls =
        for _ <- 1..2 do
          assert_receive {:timeout_called, id, reason}, 1_000
          {id, reason}
        end

      # id1 ("interactive") triggers the pause — :triggered; id2 ("normal") is cancelled — :cancelled
      assert {:triggered, :cancelled} ==
               {calls |> Enum.find_value(fn {id, r} -> id == "id1" && r end),
                calls |> Enum.find_value(fn {id, r} -> id == "id2" && r end)}
    end
  end

  # --- Additional MFA helpers needed by tests above ---

  def make_custom_result(tool_call, _content, _is_error) do
    ToolResult.make(tool_call.id, "enriched!", false)
  end

  def start_await_error(pe_pid, tool_call) do
    spawn(fn -> send(pe_pid, {:tool_result, tool_call.id, "mcp error", true}) end)
    :ok
  end

  def start_await_never(_tool_call), do: :ok
end
