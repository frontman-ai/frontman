defmodule SwarmAiTest do
  use SwarmAi.Testing, async: true

  alias SwarmAi.ToolExecution

  def start_await(test_pid, tool_call) do
    send(test_pid, {:await_started, tool_call.id, self()})
    :ok
  end

  describe "run/2" do
    test "remains running while dispatching the terminal event" do
      runtime = start_runtime!()
      test_pid = self()

      dispatch = fn event ->
        send(test_pid, {event, SwarmAi.running?(runtime, "task-handoff")})
        :ok
      end

      {:ok, pid} =
        run_agent(runtime, "task-handoff", %MockLLM{response: "done"}, dispatch_event: dispatch)

      await_exit(pid)
      assert_receive {:completed, true}
    end

    test "hands off to the next execution after terminal dispatch finishes" do
      runtime = start_runtime!()
      test_pid = self()

      dispatch = fn
        :completed ->
          send(test_pid, {:completion_broadcast, self()})

          receive do
            :finish_persistence -> :ok
          after
            2_000 -> raise "Terminal persistence was not released"
          end

        _event ->
          :ok
      end

      {:ok, pid} =
        run_agent(runtime, "task-handoff", %MockLLM{response: "done"}, dispatch_event: dispatch)

      assert_receive {:completion_broadcast, ^pid}

      next_loop = agent("task-handoff", %MockLLM{response: "follow-up"}, [])

      next_run =
        Task.async(fn ->
          send(test_pid, :starting_next_turn)
          SwarmAi.run(runtime, next_loop)
        end)

      assert_receive :starting_next_turn
      assert Task.yield(next_run, 50) == nil
      assert SwarmAi.running?(runtime, "task-handoff")

      send(pid, :finish_persistence)
      assert {:ok, next_pid} = Task.await(next_run, 2_000)
      await_exit(next_pid)
      assert_receive {:test_event, "task-handoff", :completed}
      refute SwarmAi.running?(runtime, "task-handoff")
    end

    test "prevents duplicate execution for same key" do
      runtime = start_runtime!()
      llm = %MockLLM{response: "slow", delay_ms: 500}

      {:ok, _} = run_agent(runtime, "task-dup", llm)

      assert run_agent(runtime, "task-dup", llm) == {:error, :already_running}
    end

    test "concurrent starts allow only one registered execution" do
      runtime = start_runtime!()
      llm = %MockLLM{response: "slow", delay_ms: 5000}
      start_ref = make_ref()
      parent = self()

      runners =
        for _ <- 1..8 do
          Task.async(fn ->
            send(parent, {:ready, self()})

            receive do
              ^start_ref -> :ok
            end

            run_agent(runtime, "task-race", llm)
          end)
        end

      Enum.each(runners, fn _ -> assert_receive {:ready, _pid}, 1000 end)
      Enum.each(runners, &send(&1.pid, start_ref))

      results = Enum.map(runners, &Task.await(&1, 2000))
      ok_results = Enum.filter(results, &match?({:ok, pid} when is_pid(pid), &1))

      assert [{:ok, pid}] = ok_results
      assert Enum.count(results, &(&1 == {:error, :already_running})) == length(runners) - 1
      assert SwarmAi.running?(runtime, "task-race")

      assert :ok = SwarmAi.cancel(runtime, "task-race")
      await_exit(pid)
    end
  end

  describe "running?/2" do
    test "returns true while running, false when not" do
      runtime = start_runtime!()
      refute SwarmAi.running?(runtime, "no-such")

      {:ok, _} = run_agent(runtime, "task-r", %MockLLM{response: "slow", delay_ms: 500})

      assert SwarmAi.running?(runtime, "task-r")
    end
  end

  describe "cancel/2" do
    test "dispatches cancelled (not crashed or terminated) and unregisters" do
      runtime = start_runtime!()
      {:ok, pid} = run_agent(runtime, "task-c", %MockLLM{response: "slow", delay_ms: 5000})

      assert SwarmAi.cancel(runtime, "task-c") == :ok
      await_exit(pid)

      assert_receive {:test_event, "task-c", {:cancelled, _}}
      refute_receive {:test_event, "task-c", {:crashed, _}}, 100
      refute_receive {:test_event, "task-c", {:terminated, _}}, 0
      refute SwarmAi.running?(runtime, "task-c")
    end

    test "does not interrupt terminal dispatch or emit a second terminal event" do
      runtime = start_runtime!()
      test_pid = self()

      dispatch = fn
        :completed ->
          send(test_pid, {:completion_started, self()})

          receive do
            :finish_persistence ->
              send(test_pid, :completion_persisted)
              :ok
          after
            2_000 -> raise "Terminal persistence was not released"
          end

        event ->
          send(test_pid, {:execution_event, event})
          :ok
      end

      {:ok, pid} =
        run_agent(runtime, "task-finishing", %MockLLM{response: "done"}, dispatch_event: dispatch)

      assert_receive {:completion_started, ^pid}
      ref = Process.monitor(pid)
      assert :ok = SwarmAi.cancel(runtime, "task-finishing")
      refute_receive {:DOWN, ^ref, :process, ^pid, _}, 50
      assert SwarmAi.running?(runtime, "task-finishing")

      send(pid, :finish_persistence)
      assert_receive :completion_persisted
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2000
      assert SwarmAi.active_count(runtime) == 0
      refute_receive {:execution_event, {:cancelled, _}}, 50
      refute_receive {:execution_event, {:crashed, _}}, 0
      refute_receive {:execution_event, {:terminated, _}}, 0
      refute_receive {:completion_started, _}, 0
    end

    test "returns error when not running" do
      runtime = start_runtime!()
      assert SwarmAi.cancel(runtime, "nope") == {:error, :not_running}
    end
  end

  test "cancelling an infinite Await terminates the parked worker and unregisters" do
    runtime = start_runtime!()
    test_pid = self()

    execute_tools = fn tool_calls, task_supervisor ->
      Enum.map(tool_calls, fn tool_call ->
        %ToolExecution.Await{
          tool_call: tool_call,
          timeout_ms: :infinity,
          start: {__MODULE__, :start_await, [test_pid]},
          on_error: {SwarmAi.Testing, :default_tool_error, []}
        }
      end)
      |> SwarmAi.ParallelExecutor.run(task_supervisor)
    end

    llm = tool_then_complete_llm([tool_call("approval", %{}, id: "tc1")], "done")
    {:ok, pid} = run_agent(runtime, "task-wait", llm, execute_tools: execute_tools)
    assert_receive {:await_started, "tc1", ^pid}
    assert SwarmAi.running?(runtime, "task-wait")
    refute_receive {:test_event, "task-wait", :completed}, 50

    assert :ok = SwarmAi.cancel(runtime, "task-wait")
    await_exit(pid)
    assert_receive {:test_event, "task-wait", {:cancelled, nil}}
    refute SwarmAi.running?(runtime, "task-wait")
    assert SwarmAi.active_count(runtime) == 0
    send(pid, {:tool_result, "tc1", "late answer", false})
    refute_receive {:test_event, "task-wait", :completed}, 20
    refute_receive {:test_event, "task-wait", {:failed, _}}, 0
    refute_receive {:test_event, "task-wait", {:crashed, _}}, 0
  end

  defp start_runtime! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    start_supervised!({SwarmAi, name: name})
    name
  end

  defp agent(id, llm, opts) do
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

  defp run_agent(runtime, id, llm, opts \\ []) do
    SwarmAi.run(runtime, agent(id, llm, opts))
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 2000
  end
end
