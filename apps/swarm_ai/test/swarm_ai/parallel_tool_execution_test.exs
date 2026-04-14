defmodule SwarmAi.ParallelToolExecutionTest do
  use SwarmAi.Testing, async: true

  alias SwarmAi.{ToolExecution, ToolResult}

  # --- MFA callbacks ---

  # Sends :ready to coordinator, then blocks until coordinator sends :go.
  # All N tasks must be alive simultaneously for the coordinator to release them.
  # Sequential execution deadlocks (coordinator never sees N :ready signals).
  def run_rendezvous(coordinator, tool_call) do
    send(coordinator, {:ready, self()})

    receive do
      :go -> :ok
    after
      5_000 -> raise "rendezvous timeout — tools may not be running concurrently"
    end

    ToolResult.make(tool_call.id, "Result", false)
  end

  def run_instant(tool_call), do: ToolResult.make(tool_call.id, "OK", false)
  def run_crash(_tool_call), do: raise("boom")
  def noop_timeout(_tool_call, _reason), do: :ok

  describe "batch tool execution through Runtime" do
    test "executes multiple tools concurrently" do
      runtime = start_runtime!()
      test_pid = self()
      total = 3

      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "t1", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "t2", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_3", name: "t3", arguments: "{}"}
           ], "Running..."},
          {:complete, "All done"}
        ])

      agent = test_agent(llm)

      # Collects :ready from all `total` tasks before releasing any.
      # If tools run sequentially, task 1 blocks on receive :go forever,
      # task 2 never starts, coordinator never gets total signals → timeout.
      coordinator =
        spawn(fn ->
          pids =
            Enum.map(1..total, fn _ ->
              receive do
                {:ready, pid} -> pid
              after
                5_000 -> raise "coordinator timed out — tools not running concurrently"
              end
            end)

          send(test_pid, :all_concurrent)
          Enum.each(pids, &send(&1, :go))
        end)

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          %ToolExecution.Sync{
            tool_call: tc,
            timeout_ms: 5_000,
            on_timeout_policy: :error,
            run: {__MODULE__, :run_rendezvous, [coordinator]},
            on_timeout: {__MODULE__, :noop_timeout, []}
          }
        end)
      end

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-parallel", agent, "Do work", tool_executor: executor)

      assert_receive :all_concurrent, 5_000
      await_exit(pid)
      assert_receive {:test_event, "task-parallel", {:completed, {:ok, "All done", _}}, _}, 2_000
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
