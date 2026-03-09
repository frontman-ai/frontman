defmodule SwarmAi.RuntimeTest do
  use SwarmAi.Testing, async: true

  describe "child_spec/1" do
    test "requires :name option" do
      assert_raise KeyError, fn ->
        SwarmAi.Runtime.child_spec([])
      end
    end

    test "returns a supervisor child spec" do
      spec = SwarmAi.Runtime.child_spec(name: TestRuntime)
      assert spec.type == :supervisor
      assert spec.id == {SwarmAi.Runtime, TestRuntime}
    end
  end

  describe "run/5" do
    @tag echo_agent: true
    test "runs an agent to completion", %{echo_agent: agent} do
      runtime = start_runtime!()

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-1", agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end
        )

      assert is_pid(pid)

      # Wait for completion
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
    end

    @tag echo_agent: true
    test "invokes on_complete callback on success", %{echo_agent: agent} do
      runtime = start_runtime!()
      test_pid = self()

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-complete", agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end,
          on_complete: fn result ->
            send(test_pid, {:completed, result})
          end
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
      assert_receive {:completed, {:ok, "Echo: Hello", _loop_id}}, 1000
    end

    @tag error_agent: :llm_error
    test "invokes on_error callback on failure", %{error_agent: agent} do
      runtime = start_runtime!()
      test_pid = self()

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-error", agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end,
          on_error: fn result ->
            send(test_pid, {:errored, result})
          end
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
      assert_receive {:errored, {:error, _reason, _loop_id}}, 1000
    end

    @tag echo_agent: true
    test "prevents duplicate execution for same key", %{echo_agent: agent} do
      runtime = start_runtime!()

      # Use a mock that delays so the first execution is still running
      slow_llm = %MockLLM{response: "slow", delay_ms: 500}
      slow_agent = test_agent(slow_llm)

      {:ok, _pid1} =
        SwarmAi.Runtime.run(runtime, "task-dup", slow_agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end
        )

      # Small delay to let the first task register
      Process.sleep(50)

      # Second attempt should fail
      result =
        SwarmAi.Runtime.run(runtime, "task-dup", agent, "World",
          tool_executor: fn _ -> {:ok, "done"} end
        )

      assert result == {:error, :already_running}
    end

    @tag echo_agent: true
    test "allows different keys concurrently", %{echo_agent: agent} do
      runtime = start_runtime!()

      slow_llm = %MockLLM{response: "slow", delay_ms: 200}
      slow_agent = test_agent(slow_llm)

      {:ok, pid1} =
        SwarmAi.Runtime.run(runtime, "task-a", slow_agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end
        )

      {:ok, pid2} =
        SwarmAi.Runtime.run(runtime, "task-b", agent, "World",
          tool_executor: fn _ -> {:ok, "done"} end
        )

      assert pid1 != pid2
    end

    @tag echo_agent: true
    test "returned pid is alive and registered after run succeeds", %{echo_agent: _agent} do
      runtime = start_runtime!()
      slow_llm = %MockLLM{response: "slow", delay_ms: 500}
      slow_agent = test_agent(slow_llm)

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-verified", slow_agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end
        )

      # The handshake guarantees the pid is alive and registered
      # when {:ok, pid} is returned — no race window.
      assert Process.alive?(pid)
      assert SwarmAi.Runtime.running?(runtime, "task-verified")
    end

    @tag echo_agent: true
    test "running? returns false after completion", %{echo_agent: agent} do
      runtime = start_runtime!()
      test_pid = self()

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-done", agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end,
          on_complete: fn _ ->
            # At callback time, running? should already be false
            send(test_pid, {:running_at_callback, SwarmAi.Runtime.running?(runtime, "task-done")})
          end
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
      assert_receive {:running_at_callback, false}, 1000
    end
  end

  describe "running?/2" do
    @tag echo_agent: true
    test "returns true while agent is running", %{echo_agent: _agent} do
      runtime = start_runtime!()
      slow_llm = %MockLLM{response: "slow", delay_ms: 500}
      slow_agent = test_agent(slow_llm)

      {:ok, _pid} =
        SwarmAi.Runtime.run(runtime, "task-running", slow_agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end
        )

      Process.sleep(50)
      assert SwarmAi.Runtime.running?(runtime, "task-running") == true
    end

    test "returns false when no agent is running" do
      runtime = start_runtime!()
      assert SwarmAi.Runtime.running?(runtime, "no-such-task") == false
    end
  end

  describe "cancel/2" do
    test "cancels a running execution" do
      runtime = start_runtime!()
      test_pid = self()
      slow_llm = %MockLLM{response: "slow", delay_ms: 5000}
      slow_agent = test_agent(slow_llm)

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-cancel", slow_agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end,
          on_cancelled: fn ->
            send(test_pid, :cancelled)
          end
        )

      Process.sleep(50)
      assert SwarmAi.Runtime.cancel(runtime, "task-cancel") == :ok

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 1000
      assert_receive :cancelled, 1000
    end

    test "returns error when not running" do
      runtime = start_runtime!()
      assert SwarmAi.Runtime.cancel(runtime, "no-such-task") == {:error, :not_running}
    end
  end

  describe "crash handling" do
    test "invokes on_crash with {reason, stacktrace} tuple when execution raises" do
      runtime = start_runtime!()
      test_pid = self()

      # StreamErrorLLM raises mid-stream — produces {exception, stacktrace} :DOWN reason
      crash_agent = test_agent(%StreamErrorLLM{error_message: "boom"})

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-crash", crash_agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end,
          on_crash: fn reason ->
            send(test_pid, {:crashed, reason})
          end
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 1000

      # on_crash receives a normalized {reason, stacktrace} tuple
      assert_receive {:crashed, {crash_reason, stacktrace}}, 1000
      assert is_list(stacktrace)
      # The reason should be the original exception or error term
      assert crash_reason != nil

      # Should no longer be running
      assert SwarmAi.Runtime.running?(runtime, "task-crash") == false
    end

    test "on_crash normalizes non-exception exits to {reason, []} tuple" do
      runtime = start_runtime!()
      test_pid = self()

      # Agent that calls exit(:kaboom) — produces a bare atom :DOWN reason
      exit_llm = %MockLLM{
        response: fn ->
          exit(:kaboom)
        end
      }

      exit_agent = test_agent(exit_llm)

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-exit", exit_agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end,
          on_crash: fn reason ->
            send(test_pid, {:crashed, reason})
          end
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 1000

      # Non-exception exit reasons are normalized to {reason, []}
      assert_receive {:crashed, {:kaboom, []}}, 1000
    end
  end

  describe "on_suspended callback" do
    test "on_suspended fires when tool returns :suspended" do
      runtime = start_runtime!()
      test_pid = self()

      llm =
        tool_then_complete_llm(
          [%SwarmAi.ToolCall{id: "tc_1", name: "question", arguments: ~s({"prompt":"yes?"})}],
          "Done"
        )

      agent = test_agent(llm)

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-suspend", agent, "Ask user",
          tool_executor: fn _tc -> :suspended end,
          on_suspended: fn result ->
            send(test_pid, {:suspended, result})
          end
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
      assert_receive {:suspended, {:suspended, _loop_id}}, 1000
    end

    test "on_suspended does not fire when tool completes normally" do
      runtime = start_runtime!()
      test_pid = self()

      llm =
        tool_then_complete_llm(
          [%SwarmAi.ToolCall{id: "tc_1", name: "search", arguments: ~s({"q":"test"})}],
          "Done"
        )

      agent = test_agent(llm)

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-no-suspend", agent, "Search",
          tool_executor: fn _tc -> {:ok, "results"} end,
          on_suspended: fn result ->
            send(test_pid, {:suspended, result})
          end,
          on_complete: fn result ->
            send(test_pid, {:completed, result})
          end
        )

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1000
      assert_receive {:completed, {:ok, "Done", _loop_id}}, 1000
      refute_receive {:suspended, _}, 200
    end
  end

  describe "cancel vs crash distinction" do
    test "cancel invokes on_cancelled, not on_crash" do
      runtime = start_runtime!()
      test_pid = self()
      slow_llm = %MockLLM{response: "slow", delay_ms: 5000}
      slow_agent = test_agent(slow_llm)

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-cancel-vs-crash", slow_agent, "Hello",
          tool_executor: fn _ -> {:ok, "done"} end,
          on_crash: fn _reason ->
            send(test_pid, :crash_called)
          end,
          on_cancelled: fn ->
            send(test_pid, :cancel_called)
          end
        )

      Process.sleep(50)
      SwarmAi.Runtime.cancel(runtime, "task-cancel-vs-crash")

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 1000

      # on_cancelled fires, on_crash does NOT
      assert_receive :cancel_called, 1000
      refute_receive :crash_called, 200
    end
  end

  # --- Helpers ---

  defp start_runtime! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    start_supervised!({SwarmAi.Runtime, name: name})
    name
  end
end
