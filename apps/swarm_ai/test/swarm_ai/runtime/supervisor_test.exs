defmodule SwarmAi.Runtime.SupervisorTest do
  use SwarmAi.Testing, async: true

  alias SwarmAi.Runtime
  alias SwarmAi.Runtime.ExecutionMonitor

  describe "registry crash recovery" do
    test "running tasks are terminated when registry crashes" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 5000})

      {:ok, pid} = Runtime.run(runtime, "task-reg", agent, "Hello", default_opts())
      Process.sleep(50)
      assert Runtime.running?(runtime, "task-reg")

      kill_named_process(Runtime.registry_name(runtime))
      await_exit(pid)

      # Tasks exit with :shutdown (supervisor-initiated graceful stop).
      # No :crashed event — :shutdown is not an abnormal exit in OTP.
      # See #661 for adding :terminated dispatch for these exits.
      refute_receive {:test_event, "task-reg", {:crashed, _}}, 100
    end

    test "accepts new work after registry crash" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 5000})

      {:ok, pid} = Runtime.run(runtime, "task-pre", agent, "Hello", default_opts())
      Process.sleep(50)

      kill_named_process(Runtime.registry_name(runtime))
      await_exit(pid)
      wait_for_process(Runtime.registry_name(runtime))
      wait_for_process(Runtime.task_supervisor_name(runtime))

      agent2 = test_agent(mock_llm("after crash"))
      {:ok, pid2} = Runtime.run(runtime, "task-post", agent2, "Hello", default_opts())
      await_exit(pid2)

      assert_receive {:test_event, "task-post", {:completed, {:ok, "after crash", _}}}
    end
  end

  describe "task supervisor crash recovery" do
    test "dispatches crash events for running tasks when task supervisor is killed" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 5000})

      {:ok, pid} = Runtime.run(runtime, "task-ts", agent, "Hello", default_opts())
      Process.sleep(50)

      # Killing Task.Supervisor directly — tasks exit with :killed (abnormal).
      kill_named_process(Runtime.task_supervisor_name(runtime))
      await_exit(pid)

      assert_receive {:test_event, "task-ts", {:crashed, _}}, 2000
    end

    test "accepts new work after task supervisor crash" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 5000})

      {:ok, pid} = Runtime.run(runtime, "task-pre", agent, "Hello", default_opts())
      Process.sleep(50)

      kill_named_process(Runtime.task_supervisor_name(runtime))
      await_exit(pid)
      wait_for_process(Runtime.task_supervisor_name(runtime))

      agent2 = test_agent(mock_llm("recovered"))
      {:ok, pid2} = Runtime.run(runtime, "task-post", agent2, "Hello", default_opts())
      await_exit(pid2)

      assert_receive {:test_event, "task-post", {:completed, {:ok, "recovered", _}}}
    end
  end

  describe "execution monitor crash recovery" do
    test "running tasks survive execution monitor crash" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 2000})

      {:ok, pid} = Runtime.run(runtime, "task-em", agent, "Hello", default_opts())
      Process.sleep(50)

      kill_named_process(Runtime.monitor_name(runtime))
      wait_for_process(Runtime.monitor_name(runtime))

      assert Process.alive?(pid)
      assert Runtime.running?(runtime, "task-em")
    end

    test "snapshot ETS table survives execution monitor crash" do
      runtime = start_runtime!()
      monitor = Runtime.monitor_name(runtime)
      table = ExecutionMonitor.snapshot_table_name(monitor)

      agent = test_agent(%MockLLM{response: "slow", delay_ms: 5000})
      {:ok, _pid} = Runtime.run(runtime, "task-ets", agent, "Hello", default_opts())
      Process.sleep(50)

      kill_named_process(monitor)
      wait_for_process(monitor)

      # Table still exists — tasks can write without crashing
      assert :ets.info(table) != :undefined
    end

    test "accepts new work after execution monitor crash" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 2000})

      {:ok, _pid} = Runtime.run(runtime, "task-pre", agent, "Hello", default_opts())
      Process.sleep(50)

      kill_named_process(Runtime.monitor_name(runtime))
      wait_for_process(Runtime.monitor_name(runtime))

      agent2 = test_agent(mock_llm("after monitor crash"))
      {:ok, pid2} = Runtime.run(runtime, "task-post", agent2, "Hello", default_opts())
      await_exit(pid2)

      assert_receive {:test_event, "task-post", {:completed, {:ok, "after monitor crash", _}}}
    end
  end

  describe "tasks supervisor crash recovery" do
    test "running tasks are terminated when tasks supervisor is killed" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 5000})

      {:ok, pid} = Runtime.run(runtime, "task-tsup", agent, "Hello", default_opts())
      Process.sleep(50)

      # Killing TasksSupervisor — it shuts down children gracefully,
      # so tasks exit with :shutdown (not abnormal).
      # See #661 for adding :terminated dispatch for these exits.
      kill_named_process(:"#{runtime}.TasksSupervisor")
      await_exit(pid)

      refute_receive {:test_event, "task-tsup", {:crashed, _}}, 100
    end

    test "accepts new work after tasks supervisor crash" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 5000})

      {:ok, pid} = Runtime.run(runtime, "task-pre", agent, "Hello", default_opts())
      Process.sleep(50)

      kill_named_process(:"#{runtime}.TasksSupervisor")
      await_exit(pid)
      wait_for_process(:"#{runtime}.TasksSupervisor")
      wait_for_process(Runtime.registry_name(runtime))
      wait_for_process(Runtime.task_supervisor_name(runtime))

      agent2 = test_agent(mock_llm("recovered"))
      {:ok, pid2} = Runtime.run(runtime, "task-post", agent2, "Hello", default_opts())
      await_exit(pid2)

      assert_receive {:test_event, "task-post", {:completed, {:ok, "recovered", _}}}
    end
  end

  # --- Test Dispatcher ---

  defmodule TestDispatcher do
    def dispatch(test_pid, key, event, _metadata) do
      send(test_pid, {:test_event, key, event})
    end
  end

  # --- Helpers ---

  defp start_runtime! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    test_pid = self()

    start_supervised!(
      {Runtime, name: name, event_dispatcher: {__MODULE__.TestDispatcher, :dispatch, [test_pid]}}
    )

    name
  end

  defp default_opts(extra \\ []) do
    Keyword.merge([tool_executor: fn _ -> {:ok, "done"} end], extra)
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

  defp wait_for_process(name, attempts \\ 20) do
    case GenServer.whereis(name) do
      pid when is_pid(pid) ->
        pid

      nil when attempts > 0 ->
        Process.sleep(50)
        wait_for_process(name, attempts - 1)

      nil ->
        flunk("#{inspect(name)} did not restart within timeout")
    end
  end
end
