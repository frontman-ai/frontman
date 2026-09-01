defmodule SwarmAiTest do
  use SwarmAi.Testing, async: true

  alias SwarmAi.{ToolExecution, ToolResult}

  def slow_run(tool_call) do
    Process.sleep(500)
    ToolResult.make(tool_call.id, "never", false)
  end

  def noop_timeout(_tool_call, _reason), do: :ok

  describe "run/2" do
    test "unregisters before dispatching the terminal event" do
      runtime = start_runtime!()
      test_pid = self()

      dispatch = fn event ->
        send(test_pid, {event, SwarmAi.running?(runtime, "task-handoff")})
        :ok
      end

      {:ok, pid} =
        run_agent(runtime, "task-handoff", %MockLLM{response: "done"}, dispatch_event: dispatch)

      await_exit(pid)
      assert_receive {:completed, false}
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

    test "stays exclusive after worker completion until terminal dispatch finishes" do
      assert_lifecycle_exclusive("task-terminal", fn parent ->
        send(parent, {:worker_running, self()})

        receive do
          :finish_worker -> {:error, :finished}
        end
      end)
    end

    test "stays exclusive after abnormal worker exit until crash dispatch finishes" do
      assert_lifecycle_exclusive("task-crash", fn parent ->
        send(parent, {:worker_running, self()})

        receive do
          :finish_worker -> raise "boom"
        end
      end)
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

    test "returns error when not running" do
      runtime = start_runtime!()
      assert SwarmAi.cancel(runtime, "nope") == {:error, :not_running}
    end

    test "waits for an in-flight event dispatch before terminating the executor" do
      runtime = start_runtime!()
      parent = self()

      loop =
        test_execution(%MockLLM{response: "done"}, "TestBot",
          id: "task-cancel-dispatch",
          dispatch_event: fn event ->
            case event do
              {:chunk, _, _} ->
                send(parent, {:dispatch_started, self(), event})

                receive do
                  :finish_dispatch -> :ok
                end

              _event ->
                :ok
            end
          end
        )

      {:ok, lifecycle} = SwarmAi.run(runtime, loop)
      assert_receive {:dispatch_started, ^lifecycle, {:chunk, _, _}}, 2_000
      assert :ok = SwarmAi.cancel(runtime, "task-cancel-dispatch")
      assert Process.alive?(lifecycle)

      send(lifecycle, :finish_dispatch)
      await_exit(lifecycle)
    end
  end

  describe "lifecycle ownership" do
    test "untrappable lifecycle death terminates the inner worker" do
      runtime = start_runtime!()
      parent = self()

      loop =
        test_execution(
          %MockLLM{
            response: fn ->
              send(parent, {:inner_worker, self()})

              receive do
                :continue -> send(parent, :side_effect)
              end
            end
          },
          "TestBot",
          id: "task-lifecycle-kill",
          dispatch_event: fn event -> send(parent, {:event, event}) end
        )

      {:ok, lifecycle} = SwarmAi.run(runtime, loop)
      assert_receive {:inner_worker, worker}, 2_000
      lifecycle_monitor = Process.monitor(lifecycle)
      worker_monitor = Process.monitor(worker)
      assert SwarmAi.running?(runtime, "task-lifecycle-kill")

      Process.exit(lifecycle, :kill)

      assert_receive {:DOWN, ^lifecycle_monitor, :process, ^lifecycle, :killed}, 2_000
      assert_receive {:DOWN, ^worker_monitor, :process, ^worker, :killed}, 2_000
      refute SwarmAi.running?(runtime, "task-lifecycle-kill")

      send(worker, :continue)
      refute_receive :side_effect, 100
      refute_receive {:event, _event}, 0
    end
  end

  describe "pause_agent" do
    test "pause_agent tool timeout returns :paused result, no :failed event" do
      runtime = start_runtime!()

      execute_tools = fn tool_calls, task_supervisor ->
        executions =
          Enum.map(tool_calls, fn tool_call ->
            %ToolExecution.Sync{
              tool_call: tool_call,
              timeout_ms: 10,
              on_timeout_policy: :pause_agent,
              run: {__MODULE__, :slow_run, []},
              on_timeout: {__MODULE__, :noop_timeout, []}
            }
          end)

        SwarmAi.ParallelExecutor.run(executions, task_supervisor)
      end

      llm = %MockLLM{
        response: fn ->
          {:ok,
           %SwarmAi.LLM.Response{
             content: nil,
             tool_calls: [%SwarmAi.ToolCall{id: "tc1", name: "test_tool", arguments: "{}"}],
             usage: %{input_tokens: 10, output_tokens: 5},
             raw: nil
           }}
        end
      }

      {:ok, pid} =
        run_agent(runtime, "task-pause", llm, execute_tools: execute_tools)

      await_exit(pid)

      assert_receive {:test_event, "task-pause", {:paused, {:timeout, "tc1", "test_tool", 10}}},
                     200

      refute_receive {:test_event, "task-pause", :completed}, 200
      refute_receive {:test_event, "task-pause", {:failed, _}}, 0
      refute_receive {:test_event, "task-pause", {:crashed, _}}, 0
      refute SwarmAi.running?(runtime, "task-pause")
    end
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

  defp assert_lifecycle_exclusive(task_id, response) do
    runtime = start_runtime!()
    parent = self()
    dispatch_release = make_ref()

    loop =
      test_execution(%MockLLM{response: fn -> response.(parent) end}, "TestBot",
        id: task_id,
        dispatch_event: fn event ->
          send(parent, {:terminal_dispatching, event})

          receive do
            ^dispatch_release -> :ok
          end
        end
      )

    {:ok, lifecycle} = SwarmAi.run(runtime, loop)
    assert_receive {:worker_running, worker}, 2_000
    worker_monitor = Process.monitor(worker)
    assert SwarmAi.running?(runtime, task_id)
    assert SwarmAi.run(runtime, loop) == {:error, :already_running}

    send(worker, :finish_worker)
    assert_receive {:DOWN, ^worker_monitor, :process, ^worker, _reason}, 2_000
    assert_receive {:terminal_dispatching, _event}, 2_000
    assert SwarmAi.running?(runtime, task_id)
    assert SwarmAi.run(runtime, loop) == {:error, :already_running}

    lifecycle_monitor = Process.monitor(lifecycle)
    send(lifecycle, dispatch_release)
    assert_receive {:DOWN, ^lifecycle_monitor, :process, ^lifecycle, _reason}, 2_000
    refute SwarmAi.running?(runtime, task_id)
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 2000
  end
end
