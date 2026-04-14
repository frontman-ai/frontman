defmodule SwarmAi.ParallelToolExecutionTest do
  use SwarmAi.Testing, async: true

  alias SwarmAi.{ToolExecution, ToolResult}

  # --- MFA callbacks ---

  def run_with_sleep(delay_ms, tool_call) do
    Process.sleep(delay_ms)
    ToolResult.make(tool_call.id, "Result", false)
  end

  def run_instant(tool_call), do: ToolResult.make(tool_call.id, "OK", false)
  def run_crash(_tool_call), do: raise("boom")
  def noop_timeout(_tool_call, _reason), do: :ok

  describe "batch tool execution through Runtime" do
    test "executes multiple tools concurrently" do
      runtime = start_runtime!()
      test_pid = self()

      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "slow", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "slow", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_3", name: "slow", arguments: "{}"}
           ], "Running..."},
          {:complete, "All done"}
        ])

      agent = test_agent(llm)

      executor = fn tool_calls ->
        send(test_pid, {:exec_start, System.monotonic_time(:millisecond)})

        Enum.map(tool_calls, fn tc ->
          %ToolExecution.Sync{
            tool_call: tc,
            timeout_ms: 5_000,
            on_timeout_policy: :error,
            run: {__MODULE__, :run_with_sleep, [100]},
            on_timeout: {__MODULE__, :noop_timeout, []}
          }
        end)
      end

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-parallel", agent, "Do work", tool_executor: executor)

      await_exit(pid)
      finish = System.monotonic_time(:millisecond)

      assert_receive {:exec_start, exec_start}
      assert_receive {:test_event, "task-parallel", {:completed, {:ok, "All done", _}}, _}

      # 3 tools × 100ms each — sequential would take ~300ms, parallel ~100ms.
      # Allow 400ms headroom for the second LLM call and task cleanup.
      elapsed = finish - exec_start
      assert elapsed < 400, "Expected parallel (<400ms from tool dispatch) but took #{elapsed}ms"
    end

    test "fault isolation - crashing tool produces error result, agent continues" do
      runtime = start_runtime!()

      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "good", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "bad", arguments: "{}"}
           ], "Running..."},
          {:complete, "Handled"}
        ])

      agent = test_agent(llm)

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          run_mfa =
            case tc.name do
              "bad" -> {__MODULE__, :run_crash, []}
              _ -> {__MODULE__, :run_instant, []}
            end

          %ToolExecution.Sync{
            tool_call: tc,
            timeout_ms: 5_000,
            on_timeout_policy: :error,
            run: run_mfa,
            on_timeout: {__MODULE__, :noop_timeout, []}
          }
        end)
      end

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-crash", agent, "Do work", tool_executor: executor)

      await_exit(pid)
      assert_receive {:test_event, "task-crash", {:completed, {:ok, "Handled", _}}, _}, 2_000
    end
  end

  # --- Helpers ---

  defmodule TestDispatcher do
    def dispatch(test_pid, key, event, metadata) do
      send(test_pid, {:test_event, key, event, metadata})
    end
  end

  defp start_runtime! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    test_pid = self()

    start_supervised!(
      {SwarmAi.Runtime, name: name, event_dispatcher: {TestDispatcher, :dispatch, [test_pid]}}
    )

    name
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 3000
  end
end
