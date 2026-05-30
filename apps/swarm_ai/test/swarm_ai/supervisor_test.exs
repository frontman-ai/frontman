defmodule SwarmAi.SupervisorTest do
  use SwarmAi.Testing, async: true

  describe "runtime supervision" do
    test "starts execution supervisor" do
      runtime = start_runtime!()

      assert Process.whereis(SwarmAi.execution_supervisor_name(runtime))
    end
  end

  describe "registry crash recovery" do
    test "running tasks are terminated when registry crashes" do
      runtime = start_runtime!()

      {:ok, pid} = run_agent(runtime, "task-reg", %MockLLM{response: "slow", delay_ms: 5000})
      assert SwarmAi.running?(runtime, "task-reg")

      kill_named_process(SwarmAi.registry_name(runtime))
      await_exit(pid)

      assert_receive {:test_event, "task-reg", {:terminated, _}}, 2000
      refute_receive {:test_event, "task-reg", {:crashed, _}}, 100
    end

    test "accepts new work after registry crash" do
      runtime = start_runtime!()

      {:ok, pid} = run_agent(runtime, "task-pre", %MockLLM{response: "slow", delay_ms: 5000})

      kill_named_process(SwarmAi.registry_name(runtime))
      await_exit(pid)

      {:ok, pid2} = run_after_recovery(runtime, "task-post", mock_llm("after crash"))
      await_exit(pid2)

      assert_receive {:test_event, "task-post", {:completed, nil}}
    end
  end

  describe "task supervisor crash recovery" do
    test "dispatches terminated events for running executions when task supervisor is killed" do
      runtime = start_runtime!()

      {:ok, pid} = run_agent(runtime, "task-ts", %MockLLM{response: "slow", delay_ms: 5000})

      kill_named_process(SwarmAi.task_supervisor_name(runtime))
      await_exit(pid)

      assert_receive {:test_event, "task-ts", {:terminated, _}}, 2000
      refute_receive {:test_event, "task-ts", {:crashed, _}}, 100
    end

    test "accepts new work after task supervisor crash" do
      runtime = start_runtime!()

      {:ok, pid} = run_agent(runtime, "task-pre", %MockLLM{response: "slow", delay_ms: 5000})

      kill_named_process(SwarmAi.task_supervisor_name(runtime))
      await_exit(pid)

      {:ok, pid2} = run_after_recovery(runtime, "task-post", mock_llm("recovered"))
      await_exit(pid2)

      assert_receive {:test_event, "task-post", {:completed, nil}}
    end
  end

  defmodule TestDispatcher do
    def dispatch(test_pid, key, event, _context) do
      send(test_pid, {:test_event, key, event})
    end
  end

  defp start_runtime! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    test_pid = self()

    start_supervised!(
      {SwarmAi, name: name, event_dispatcher: {__MODULE__.TestDispatcher, :dispatch, [test_pid]}}
    )

    name
  end

  defp agent(_runtime, id, llm), do: test_execution(llm, "TestBot", id: id)

  defp run_agent(runtime, id, llm) do
    SwarmAi.run(runtime, agent(runtime, id, llm))
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
