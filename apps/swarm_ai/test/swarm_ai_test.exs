defmodule SwarmAiTest do
  use SwarmAi.Testing, async: true

  alias SwarmAi.{ToolExecution, ToolResult}

  def slow_run(tool_call) do
    Process.sleep(500)
    ToolResult.make(tool_call.id, "never", false)
  end

  def noop_timeout(_tool_call, _reason), do: :ok

  describe "run/2" do
    test "runs without event dispatcher" do
      runtime = start_runtime_without_dispatcher!()

      {:ok, pid} = run_agent(runtime, "task-no-dispatch", %MockLLM{response: "done"})
      await_exit(pid)

      refute SwarmAi.running?(runtime, "task-no-dispatch")
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

    test "returns error when not running" do
      runtime = start_runtime!()
      assert SwarmAi.cancel(runtime, "nope") == {:error, :not_running}
    end
  end

  describe "pause_agent" do
    test "pause_agent tool timeout returns :paused result, no :failed event" do
      runtime = start_runtime!()

      # Executor returns Sync executions with 10ms timeout and :pause_agent policy.
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
             usage: %SwarmAi.LLM.Usage{input_tokens: 10, output_tokens: 5},
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

  defp start_runtime_without_dispatcher! do
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
