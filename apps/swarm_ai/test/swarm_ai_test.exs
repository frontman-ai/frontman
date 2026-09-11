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

      {:ok, pid} =
        run_agent(runtime, "task-handoff", %MockLLM{response: "done"},
          dispatch_event: completion_dispatch(test_pid)
        )

      ref = await_worker_event(pid, {:completion_started, pid})

      next_loop = agent("task-handoff", %MockLLM{response: "follow-up"}, [])

      next_run = Task.async(fn -> SwarmAi.run(runtime, next_loop) end)

      assert_waiting_for_execution(next_run.pid, pid)
      assert SwarmAi.running?(runtime, "task-handoff")

      send(pid, :finish_persistence)
      assert {:ok, next_pid} = Task.await(next_run, 2_000)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2_000
      await_exit(next_pid)
      assert_receive {:test_event, "task-handoff", :completed}, 2_000
      assert_unregistered(runtime, "task-handoff")
    end

    test "prevents duplicate execution for same key" do
      runtime = start_runtime!()
      llm = blocked_llm()

      {:ok, pid} = run_agent(runtime, "task-dup", llm)
      await_worker_event(pid, {:llm_started, pid})

      assert run_agent(runtime, "task-dup", llm) == {:error, :already_running}
      send(pid, :finish_llm)
      await_exit(pid)
    end

    test "concurrent starts allow only one registered execution" do
      runtime = start_runtime!()
      llm = blocked_llm()
      start_ref = make_ref()
      parent = self()

      runners =
        for _ <- 1..8 do
          Task.async(fn ->
            send(parent, {:ready, self()})

            receive do
              ^start_ref -> :ok
            after
              2_000 -> raise "Concurrent start was not released"
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

      {:ok, pid} = run_agent(runtime, "task-r", blocked_llm())
      await_worker_event(pid, {:llm_started, pid})

      assert SwarmAi.running?(runtime, "task-r")
      send(pid, :finish_llm)
      await_exit(pid)
      assert_unregistered(runtime, "task-r")
    end
  end

  describe "cancel/2" do
    test "dispatches cancelled (not crashed or terminated) and unregisters" do
      runtime = start_runtime!()
      {:ok, pid} = run_agent(runtime, "task-c", blocked_llm())
      await_worker_event(pid, {:llm_started, pid})

      assert SwarmAi.cancel(runtime, "task-c") == :ok
      await_exit(pid)

      assert_receive {:test_event, "task-c", {:cancelled, _}}, 2_000
      assert SwarmAi.active_count(runtime) == 0
      refute_receive {:test_event, "task-c", {:crashed, _}}, 0
      refute_receive {:test_event, "task-c", {:terminated, _}}, 0
      refute SwarmAi.running?(runtime, "task-c")
    end

    test "does not interrupt terminal dispatch or emit a second terminal event" do
      runtime = start_runtime!()
      test_pid = self()

      {:ok, pid} =
        run_agent(runtime, "task-finishing", %MockLLM{response: "done"},
          dispatch_event: completion_dispatch(test_pid)
        )

      ref = await_worker_event(pid, {:completion_started, pid})
      assert :ok = SwarmAi.cancel(runtime, "task-finishing")
      assert SwarmAi.running?(runtime, "task-finishing")

      send(pid, :finish_persistence)
      await_worker_event(pid, :completion_persisted, ref)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 2000
      assert SwarmAi.active_count(runtime) == 0
      refute_receive {:unexpected_terminal, ^pid, _}, 0
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
    await_worker_event(pid, {:await_started, "tc1", pid})
    assert SwarmAi.running?(runtime, "task-wait")

    assert :ok = SwarmAi.cancel(runtime, "task-wait")
    await_exit(pid)
    assert_receive {:test_event, "task-wait", {:cancelled, nil}}, 2_000
    refute SwarmAi.running?(runtime, "task-wait")
    assert SwarmAi.active_count(runtime) == 0
    send(pid, {:tool_result, "tc1", "late answer", false})
    refute_receive {:test_event, "task-wait", :completed}, 0
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

  defp completion_dispatch(test_pid) do
    fn
      :completed ->
        send(test_pid, {:completion_started, self()})

        receive do
          :finish_persistence ->
            send(test_pid, :completion_persisted)
            :ok
        after
          2_000 -> raise "Terminal persistence was not released"
        end

      {:chunk, _, _} ->
        :ok

      {:response, _, _} ->
        :ok

      event ->
        send(test_pid, {:unexpected_terminal, self(), event})
        :ok
    end
  end

  defp blocked_llm do
    test_pid = self()

    %MockLLM{
      response: fn ->
        send(test_pid, {:llm_started, self()})

        receive do
          :finish_llm -> {:ok, %SwarmAi.LLM.Response{content: "done"}}
        after
          2_000 -> raise "Mock LLM was not released"
        end
      end
    }
  end

  defp await_worker_event(pid, event),
    do: await_worker_event(pid, event, Process.monitor(pid))

  defp await_worker_event(pid, event, ref) do
    receive do
      ^event ->
        ref

      {:DOWN, ^ref, :process, ^pid, reason} ->
        flunk("Worker exited: #{inspect(reason)}")

      {:unexpected_terminal, ^pid, terminal} ->
        flunk("Unexpected terminal: #{inspect(terminal)}")

      {:test_event, _, {status, _} = terminal}
      when status in [:failed, :cancelled, :crashed, :terminated] ->
        flunk("Unexpected terminal: #{inspect(terminal)}")
    after
      2_000 -> flunk("Worker did not send #{inspect(event)}: #{inspect(Process.info(pid))}")
    end
  end

  defp assert_waiting_for_execution(
         caller,
         worker,
         deadline \\ System.monotonic_time(:millisecond) + 2_000
       ) do
    case Process.info(caller, [:status, :current_function, :monitors]) do
      [
        status: :waiting,
        current_function: {SwarmAi.Runtime, :await_finishing_execution, 2},
        monitors: monitors
      ] ->
        assert {:process, worker} in monitors

      nil ->
        flunk("Next caller exited without waiting for terminal persistence")

      info ->
        assert System.monotonic_time(:millisecond) < deadline,
               "Next caller did not wait for terminal persistence: #{inspect(info)}"

        :erlang.yield()
        assert_waiting_for_execution(caller, worker, deadline)
    end
  end

  defp assert_unregistered(
         runtime,
         task_id,
         deadline \\ System.monotonic_time(:millisecond) + 2_000
       ) do
    case SwarmAi.running?(runtime, task_id) do
      false ->
        :ok

      true ->
        assert System.monotonic_time(:millisecond) < deadline,
               "Registry did not remove the exited execution for #{task_id}"

        :erlang.yield()
        assert_unregistered(runtime, task_id, deadline)
    end
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 2000
  end
end
