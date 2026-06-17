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

  def run_serial_gate(test_pid, tool_call) do
    send(test_pid, {:serial_started, tool_call.name, self()})

    receive do
      :go -> :ok
    after
      5_000 -> raise "serial gate timeout"
    end

    send(test_pid, {:serial_finished, tool_call.name})
    ToolResult.make(tool_call.id, "Result", false)
  end

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

      execute_tools = fn tool_calls, task_supervisor ->
        Enum.map(tool_calls, fn tc ->
          %ToolExecution.Sync{
            tool_call: tc,
            timeout_ms: 5_000,
            on_timeout_policy: :error,
            run: {__MODULE__, :run_rendezvous, [coordinator]},
            on_timeout: {__MODULE__, :noop_timeout, []}
          }
        end)
        |> SwarmAi.ParallelExecutor.run(task_supervisor)
      end

      {:ok, pid} =
        run_execution(runtime, "task-parallel", llm, execute_tools: execute_tools)

      assert_receive :all_concurrent, 5_000
      await_exit(pid)
      assert_receive {:test_event, "task-parallel", :completed}, 2_000
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

      execute_tools = fn tool_calls, task_supervisor ->
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
        |> SwarmAi.ParallelExecutor.run(task_supervisor)
      end

      {:ok, pid} =
        run_execution(runtime, "task-crash", llm, execute_tools: execute_tools)

      await_exit(pid)
      assert_receive {:test_event, "task-crash", :completed}, 2_000
    end

    test "can execute a tool batch serially" do
      runtime = start_runtime!()
      test_pid = self()

      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "t1", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "t2", arguments: "{}"}
           ], "Running..."},
          {:complete, "All done"}
        ])

      execute_tools = fn tool_calls, task_supervisor ->
        Enum.map(tool_calls, fn tc ->
          %ToolExecution.Sync{
            tool_call: tc,
            timeout_ms: 5_000,
            on_timeout_policy: :error,
            run: {__MODULE__, :run_serial_gate, [test_pid]},
            on_timeout: {__MODULE__, :noop_timeout, []}
          }
        end)
        |> SwarmAi.ParallelExecutor.run_serial(task_supervisor)
      end

      {:ok, pid} =
        run_execution(runtime, "task-serial", llm, execute_tools: execute_tools)

      assert_receive {:serial_started, "t1", first_pid}, 1_000
      refute_receive {:serial_started, "t2", _}, 100
      send(first_pid, :go)
      assert_receive {:serial_finished, "t1"}, 1_000
      assert_receive {:serial_started, "t2", second_pid}, 1_000
      send(second_pid, :go)

      await_exit(pid)
      assert_receive {:test_event, "task-serial", :completed}, 2_000
    end
  end

  # --- Helpers ---

  defp start_runtime! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    start_supervised!({SwarmAi, name: name})
    name
  end

  defp run_execution(runtime, id, llm, opts) do
    test_pid = self()

    loop =
      test_execution(
        llm,
        "TestBot",
        Keyword.merge(
          [
            id: id,
            messages: [SwarmAi.Message.system("You are TestBot"), SwarmAi.Message.user("Do work")],
            dispatch_event: fn event ->
              send(test_pid, {:test_event, id, event})
              :ok
            end
          ],
          opts
        )
      )

    SwarmAi.run(runtime, loop)
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 3000
  end
end
