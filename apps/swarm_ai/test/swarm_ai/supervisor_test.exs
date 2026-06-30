defmodule SwarmAi.SupervisorTest do
  use SwarmAi.Testing, async: false

  describe "runtime supervision" do
    test "starts runtime process under provided runtime name" do
      runtime = start_runtime!()

      assert Process.whereis(runtime)
    end

    test "starts execution supervisor" do
      runtime = start_runtime!()

      assert Process.whereis(SwarmAi.Runtime.execution_supervisor_name(runtime))
    end
  end

  describe "execution terminal semantics" do
    test "normal completion dispatches completed and no watcher terminal event" do
      runtime = start_runtime!()

      {:ok, pid} = run_agent(runtime, "task-normal", mock_llm("done"))
      await_exit(pid)

      assert_receive {:test_event, "task-normal", :completed}, 2000
      assert_steady_state(runtime, "task-normal")
    end

    test "cancel dispatches cancelled with nil reason" do
      runtime = start_runtime!()
      {:ok, pid} = run_agent(runtime, "task-cancel", %MockLLM{response: "slow", delay_ms: 5000})

      assert :ok = SwarmAi.cancel(runtime, "task-cancel")
      await_exit(pid)

      assert_receive {:test_event, "task-cancel", {:cancelled, nil}}, 2000
      assert_steady_state(runtime, "task-cancel")
    end

    test "shutdown dispatches terminated with nil reason" do
      runtime = start_runtime!()
      {:ok, pid} = run_agent(runtime, "task-shutdown", %MockLLM{response: "slow", delay_ms: 5000})

      Process.exit(pid, :shutdown)
      await_exit(pid)

      assert_receive {:test_event, "task-shutdown", {:terminated, nil}}, 2000
      assert_steady_state(runtime, "task-shutdown")
    end

    test "shutdown tuple dispatches terminated with inner reason" do
      runtime = start_runtime!()

      {:ok, pid} =
        run_agent(runtime, "task-shutdown-reason", %MockLLM{response: "slow", delay_ms: 5000})

      Process.exit(pid, {:shutdown, :deploy})
      await_exit(pid)

      assert_receive {:test_event, "task-shutdown-reason", {:terminated, :deploy}}, 2000
      assert_steady_state(runtime, "task-shutdown-reason")
    end

    test "killed process dispatches terminated with killed reason" do
      runtime = start_runtime!()
      {:ok, pid} = run_agent(runtime, "task-kill", %MockLLM{response: "slow", delay_ms: 5000})

      Process.exit(pid, :kill)
      await_exit(pid)

      assert_receive {:test_event, "task-kill", {:terminated, :killed}}, 2000
      assert_steady_state(runtime, "task-kill")
    end

    test "crash dispatches crashed with formatted exit message" do
      runtime = start_runtime!()

      llm =
        multi_turn_llm([
          {:tool_calls, [%ToolCall{id: "tc-crash", name: "crash", arguments: "{}"}], "Running..."}
        ])

      execute_tools = fn _tool_calls, _task_supervisor -> raise "boom" end

      {:ok, pid} = run_agent(runtime, "task-crash", llm, execute_tools: execute_tools)
      await_exit(pid)

      assert_receive {:test_event, "task-crash", {:crashed, %{message: message}}}, 2000
      assert message =~ "boom"
      assert_steady_state(runtime, "task-crash")
    end
  end

  describe "active execution count" do
    test "counts running executions and returns to zero after completion" do
      runtime = start_runtime!()

      assert SwarmAi.active_count(runtime) == 0

      {:ok, pid} =
        run_agent(runtime, "task-count-normal", %MockLLM{response: "slow", delay_ms: 5000})

      assert SwarmAi.active_count(runtime) == 1

      Process.exit(pid, :shutdown)
      await_exit(pid)

      assert_active_count(runtime, 0)
    end

    test "returns to zero after crash" do
      runtime = start_runtime!()

      llm =
        multi_turn_llm([
          {:tool_calls, [%ToolCall{id: "tc-count-crash", name: "crash", arguments: "{}"}],
           "Running..."}
        ])

      execute_tools = fn _tool_calls, _task_supervisor -> raise "boom" end

      {:ok, pid} = run_agent(runtime, "task-count-crash", llm, execute_tools: execute_tools)

      assert SwarmAi.active_count(runtime) == 1

      await_exit(pid)

      assert_active_count(runtime, 0)
    end
  end

  describe "response event identity" do
    test "shares response ordinal and timestamp across chunks and closing response" do
      runtime = start_runtime!()
      {:ok, pid} = run_agent(runtime, "task-events", mock_llm("hello"))
      await_exit(pid)

      assert_receive {:test_event, "task-events", {:chunk, metadata, _chunk}}
      assert %{ordinal: 0, timestamp: %DateTime{}} = metadata

      assert_receive {:test_event, "task-events", {:response, ^metadata, _response}}
    end
  end

  describe "registry crash recovery" do
    test "running tasks are terminated when registry crashes" do
      runtime = start_runtime!()

      {:ok, pid} = run_agent(runtime, "task-reg", %MockLLM{response: "slow", delay_ms: 5000})
      assert SwarmAi.running?(runtime, "task-reg")

      kill_named_process(SwarmAi.Runtime.Registry.name(runtime))
      await_exit(pid)

      assert_receive {:test_event, "task-reg", {:terminated, _}}, 2000
      refute_receive {:test_event, "task-reg", {:crashed, _}}, 100
    end

    test "accepts new work after registry crash" do
      runtime = start_runtime!()

      {:ok, pid} = run_agent(runtime, "task-pre", %MockLLM{response: "slow", delay_ms: 5000})

      kill_named_process(SwarmAi.Runtime.Registry.name(runtime))
      await_exit(pid)

      {:ok, pid2} = run_after_recovery(runtime, "task-post", mock_llm("after crash"))
      await_exit(pid2)

      assert_receive {:test_event, "task-post", :completed}
    end
  end

  describe "task supervisor crash recovery" do
    test "dispatches terminated events for running executions when task supervisor is killed" do
      runtime = start_runtime!()

      {:ok, pid} = run_agent(runtime, "task-ts", %MockLLM{response: "slow", delay_ms: 5000})

      kill_named_process(SwarmAi.Runtime.task_supervisor_name(runtime))
      await_exit(pid)

      assert_receive {:test_event, "task-ts", {:terminated, _}}, 2000
      refute_receive {:test_event, "task-ts", {:crashed, _}}, 100
    end

    test "dispatches terminated events for killed execution workers" do
      runtime = start_runtime!()

      {:ok, pid} = run_agent(runtime, "task-kill", %MockLLM{response: "slow", delay_ms: 5000})

      Process.exit(pid, :kill)
      await_exit(pid)

      assert_receive {:test_event, "task-kill", {:terminated, :killed}}, 2000
      refute_receive {:test_event, "task-kill", {:crashed, _}}, 100
    end

    test "accepts new work after task supervisor crash" do
      runtime = start_runtime!()

      {:ok, pid} = run_agent(runtime, "task-pre", %MockLLM{response: "slow", delay_ms: 5000})

      kill_named_process(SwarmAi.Runtime.task_supervisor_name(runtime))
      await_exit(pid)

      {:ok, pid2} = run_after_recovery(runtime, "task-post", mock_llm("recovered"))
      await_exit(pid2)

      assert_receive {:test_event, "task-post", :completed}
    end
  end

  defp start_runtime! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    start_supervised!({SwarmAi, name: name})
    name
  end

  defp agent(_runtime, id, llm) do
    test_pid = self()

    test_execution(llm, "TestBot",
      id: id,
      dispatch_event: fn event ->
        send(test_pid, {:test_event, id, event})
        :ok
      end
    )
  end

  defp run_agent(runtime, id, llm) do
    SwarmAi.run(runtime, agent(runtime, id, llm))
  end

  defp run_agent(runtime, id, llm, opts) do
    SwarmAi.run(runtime, agent(runtime, id, llm, opts))
  end

  defp agent(_runtime, id, llm, opts) do
    test_pid = self()

    test_execution(
      llm,
      "TestBot",
      Keyword.merge(
        [
          id: id,
          dispatch_event: fn event ->
            send(test_pid, {:test_event, id, event})
            :ok
          end
        ],
        opts
      )
    )
  end

  defp assert_steady_state(runtime, task_id) do
    assert_not_running(runtime, task_id)
    refute_receive {:test_event, ^task_id, {:cancelled, _}}, 50
    refute_receive {:test_event, ^task_id, {:terminated, _}}, 0
    refute_receive {:test_event, ^task_id, {:crashed, _}}, 0
  end

  defp assert_not_running(runtime, task_id, attempts \\ 20)

  defp assert_not_running(runtime, task_id, 0) do
    refute SwarmAi.running?(runtime, task_id)
  end

  defp assert_not_running(runtime, task_id, attempts) do
    case SwarmAi.running?(runtime, task_id) do
      false ->
        :ok

      true ->
        Process.sleep(10)
        assert_not_running(runtime, task_id, attempts - 1)
    end
  end

  defp assert_active_count(runtime, expected, attempts \\ 20)

  defp assert_active_count(runtime, expected, 0) do
    assert SwarmAi.active_count(runtime) == expected
  end

  defp assert_active_count(runtime, expected, attempts) do
    case SwarmAi.active_count(runtime) do
      ^expected ->
        :ok

      _count ->
        Process.sleep(10)
        assert_active_count(runtime, expected, attempts - 1)
    end
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 2000
  end

  defp kill_named_process(name) do
    pid = GenServer.whereis(name)
    assert pid != nil, "expected #{inspect(name)} to be alive"
    Process.exit(pid, :kill)
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1000
  end

  defp run_after_recovery(runtime, id, llm, attempts \\ 20)

  defp run_after_recovery(_runtime, _id, _llm, 0) do
    flunk("SwarmAi.run still failing after recovery")
  end

  defp run_after_recovery(runtime, id, llm, attempts) do
    run_agent(runtime, id, llm)
  rescue
    ArgumentError ->
      Process.sleep(50)
      run_after_recovery(runtime, id, llm, attempts - 1)
  catch
    :exit, _ ->
      Process.sleep(50)
      run_after_recovery(runtime, id, llm, attempts - 1)
  end
end
