defmodule SwarmAi.ParallelToolExecutionTest do
  use SwarmAi.Testing, async: true

  alias SwarmAi.{ToolExecution, ToolResult}

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

  def start_await(test_pid, tool_call) do
    send(test_pid, {:await_started, tool_call.id, self()})
    :ok
  end

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
      context = make_ref()

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
        send(test_pid, {:captured_context, context})

        Enum.map(tool_calls, fn tc ->
          %ToolExecution.Sync{
            tool_call: tc,
            timeout_ms: 5_000,
            run: {__MODULE__, :run_rendezvous, [coordinator]},
            on_error: {SwarmAi.Testing, :default_tool_error, []}
          }
        end)
        |> SwarmAi.ParallelExecutor.run(task_supervisor)
      end

      {:ok, pid} =
        run_execution(runtime, "task-parallel", llm, execute_tools: execute_tools)

      assert_receive {:captured_context, ^context}, 5_000
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
            run: run_mfa,
            on_error: {SwarmAi.Testing, :default_tool_error, []}
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
            run: {__MODULE__, :run_serial_gate, [test_pid]},
            on_error: {SwarmAi.Testing, :default_tool_error, []}
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

  test "a delayed interactive answer continues the same loop to completion" do
    runtime = start_runtime!()
    test_pid = self()

    llm = tool_then_complete_llm([tool_call("approval", %{}, id: "human")], "done")

    execute_tools = fn [tool_call], task_supervisor ->
      execution = %ToolExecution.Await{
        tool_call: tool_call,
        timeout_ms: :infinity,
        start: {__MODULE__, :start_await, [test_pid]},
        on_error: {SwarmAi.Testing, :default_tool_error, []}
      }

      SwarmAi.ParallelExecutor.run(
        [execution],
        task_supervisor,
        wait_observer(runtime, "task-human", test_pid)
      )
      |> tap(fn results -> send(test_pid, {:tool_results, self(), results}) end)
    end

    {:ok, pid} =
      run_execution(runtime, "task-human", %{llm | delay_ms: 150}, execute_tools: execute_tools)

    assert_receive {:await_started, "human", ^pid}, 1_000
    assert_receive {:waiting, true}, 1_000
    assert SwarmAi.active_count(runtime) == 0
    assert SwarmAi.running?(runtime, "task-human")
    assert Process.alive?(pid)

    send(pid, {:tool_result, "human", "approved", false})
    await_exit(pid)

    expected = ToolResult.make("human", "approved", false)
    assert_received {:tool_results, ^pid, {:ok, [^expected]}}
    assert_received {:test_event, "task-human", :completed}
    refute_received {:test_event, "task-human", {:failed, _}}
  end

  test "a mixed batch counts until only infinite-deadline tools remain" do
    runtime = start_runtime!()
    test_pid = self()
    key = "mixed-waits"

    calls =
      Enum.map(["human1", "human2", "remote_write", "backend_write"], &tool_call(&1, %{}, id: &1))

    llm = tool_then_complete_llm(calls, "done")

    execute_tools = fn tool_calls, supervisor ->
      executions = Enum.map(tool_calls, &mixed_execution(&1, test_pid))
      SwarmAi.ParallelExecutor.run(executions, supervisor, wait_observer(runtime, key, test_pid))
    end

    {:ok, pid} = run_execution(runtime, key, llm, execute_tools: execute_tools)
    assert_receive {:await_started, "remote_write", ^pid}, 1_000
    assert_receive {:serial_started, "backend_write", backend}, 1_000
    assert_receive {:waiting, false}, 1_000
    assert SwarmAi.active_count(runtime) == 1

    send(pid, {:tool_result, "remote_write", "saved", false})
    refute_receive {:waiting, true}, 50
    assert SwarmAi.active_count(runtime) == 1

    send(backend, :go)
    assert_receive {:waiting, true}, 1_000
    assert SwarmAi.active_count(runtime) == 0
    assert SwarmAi.running?(runtime, key)

    send(pid, {:tool_result, "human1", "yes", false})
    assert_receive {:waiting, true}, 1_000
    assert SwarmAi.active_count(runtime) == 0

    send(pid, {:tool_result, "human2", "yes", false})
    await_exit(pid)
    assert_receive {:test_event, ^key, :completed}, 1_000
    assert SwarmAi.active_count(runtime) == 0
  end

  defp mixed_execution(%{name: "backend_write"} = call, test_pid) do
    %ToolExecution.Sync{
      tool_call: call,
      timeout_ms: 5_000,
      run: {__MODULE__, :run_serial_gate, [test_pid]},
      on_error: {SwarmAi.Testing, :default_tool_error, []}
    }
  end

  defp mixed_execution(call, test_pid) do
    %ToolExecution.Await{
      tool_call: call,
      timeout_ms: if(call.name == "remote_write", do: 5_000, else: :infinity),
      start: {__MODULE__, :start_await, [test_pid]},
      on_error: {SwarmAi.Testing, :default_tool_error, []}
    }
  end

  defp wait_observer(runtime, key, test_pid) do
    fn waiting ->
      :ok = SwarmAi.awaiting_input(runtime, key, waiting)
      send(test_pid, {:waiting, waiting})
      :ok
    end
  end

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
            messages: [SwarmAi.Message.system("You are TestBot"), SwarmAi.Message.user("Do work")],
            dispatch_event: fn event ->
              send(test_pid, {:test_event, id, event})
              :ok
            end
          ],
          opts
        )
      )

    SwarmAi.run(runtime, id, loop)
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 3000
  end
end
