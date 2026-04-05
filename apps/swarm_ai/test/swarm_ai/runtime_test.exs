defmodule SwarmAi.RuntimeTest do
  use SwarmAi.Testing, async: true

  alias SwarmAi.{ToolExecution, ToolResult}

  # --- MFA callbacks for ToolExecution structs ---

  def instant_run(tool_call), do: ToolResult.make(tool_call.id, "done", false)
  def slow_run(tool_call) do
    Process.sleep(500)
    ToolResult.make(tool_call.id, "never", false)
  end
  def noop_timeout(_tool_call, _reason), do: :ok

  describe "child_spec/1" do
    test "requires :name option" do
      assert_raise KeyError, fn ->
        SwarmAi.Runtime.child_spec([])
      end
    end

    test "returns a supervisor child spec" do
      spec = SwarmAi.Runtime.child_spec(name: TestRuntime)
      assert spec.type == :supervisor
      assert spec.id == {SwarmAi.Runtime, TestRuntime}
    end
  end

  describe "run/5" do
    test "dispatches completed event on success" do
      runtime = start_runtime!()
      agent = test_agent(mock_llm("Echo: Hello"))

      {:ok, pid} =
        SwarmAi.Runtime.run(
          runtime,
          "task-complete",
          agent,
          "Hello",
          default_opts(metadata: %{my_key: "my_val"})
        )

      await_exit(pid)

      assert_receive {:test_event, "task-complete", {:completed, {:ok, "Echo: Hello", _loop_id}},
                      _metadata}

      refute SwarmAi.Runtime.running?(runtime, "task-complete")
    end

    test "dispatches completed event with metadata passed to dispatcher" do
      runtime = start_runtime!()
      agent = test_agent(mock_llm("Echo: Hello"))

      {:ok, pid} =
        SwarmAi.Runtime.run(
          runtime,
          "task-meta",
          agent,
          "Hello",
          default_opts(metadata: %{my_key: "my_val"})
        )

      await_exit(pid)

      assert_receive {:test_event, "task-meta", {:completed, {:ok, "Echo: Hello", _loop_id}},
                      metadata}

      assert metadata.my_key == "my_val"
    end

    test "dispatches failed event on LLM error" do
      runtime = start_runtime!()
      agent = test_agent(%ErrorLLM{error: :llm_api_failure})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-error", agent, "Hello", default_opts())

      await_exit(pid)

      assert_receive {:test_event, "task-error", {:failed, {:error, _reason, _loop_id}},
                      _metadata}
    end

    test "prevents duplicate execution for same key" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 500})

      {:ok, _} = SwarmAi.Runtime.run(runtime, "task-dup", agent, "Hello", default_opts())

      assert SwarmAi.Runtime.run(runtime, "task-dup", agent, "World", default_opts()) ==
               {:error, :already_running}
    end

    test "executor timeout_policy: :error returns error ToolResult and agent continues" do
      runtime = start_runtime!()

      # Executor returns Sync executions with 10ms timeout and :error policy.
      slow_executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          %ToolExecution.Sync{
            tool_call: tc,
            timeout_ms: 10,
            on_timeout_policy: :error,
            run: {__MODULE__, :slow_run, []},
            on_timeout: {__MODULE__, :noop_timeout, []}
          }
        end)
      end

      llm =
        SwarmAi.Testing.multi_turn_llm([
          {:tool_calls, [%SwarmAi.ToolCall{id: "tc1", name: "test_tool", arguments: "{}"}],
           "calling"},
          {:complete, "done after timeout error"}
        ])

      agent = test_agent(llm)

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-tool-def", agent, "Hello",
          tool_executor: slow_executor
        )

      await_exit(pid)

      # Should complete (error ToolResult returned to LLM, LLM responds with final message)
      assert_receive {:test_event, "task-tool-def", {:completed, {:ok, "done after timeout error", _}},
                      _metadata},
                     3_000
    end
  end

  describe "running?/2" do
    test "returns true while running, false when not" do
      runtime = start_runtime!()
      assert SwarmAi.Runtime.running?(runtime, "no-such") == false

      agent = test_agent(%MockLLM{response: "slow", delay_ms: 500})
      {:ok, _} = SwarmAi.Runtime.run(runtime, "task-r", agent, "Hello", default_opts())

      assert SwarmAi.Runtime.running?(runtime, "task-r") == true
    end
  end

  describe "cancel/2" do
    test "dispatches cancelled (not crashed or terminated) and unregisters" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 5000})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-c", agent, "Hello", default_opts())

      assert SwarmAi.Runtime.cancel(runtime, "task-c") == :ok
      await_exit(pid)

      assert_receive {:test_event, "task-c", {:cancelled, _}, _metadata}
      refute_receive {:test_event, "task-c", {:crashed, _}, _}, 100
      refute_receive {:test_event, "task-c", {:terminated, _}, _}, 0
      refute SwarmAi.Runtime.running?(runtime, "task-c")
    end

    test "returns error when not running" do
      runtime = start_runtime!()
      assert SwarmAi.Runtime.cancel(runtime, "nope") == {:error, :not_running}
    end
  end

  describe "crash handling" do
    test "stream raise is caught gracefully and dispatches failed (not crashed)" do
      runtime = start_runtime!()
      agent = test_agent(%StreamErrorLLM{error_message: "boom"})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-crash", agent, "Hello", default_opts())
      await_exit(pid)

      # Stream raises are now caught by try/rescue in execute_llm_call and
      # routed through Loop.handle_error → {:failed, ...} instead of crashing.
      assert_receive {:test_event, "task-crash", {:failed, {:error, reason, _loop_id}}, _metadata}
      assert %RuntimeError{message: "boom"} = reason
      refute SwarmAi.Runtime.running?(runtime, "task-crash")
    end

    test "dispatches crashed with {reason, []} for non-exception exits" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: fn -> exit(:kaboom) end})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-exit", agent, "Hello", default_opts())
      await_exit(pid)

      assert_receive {:test_event, "task-exit", {:crashed, %{reason: :kaboom, stacktrace: []}},
                      _metadata}
    end
  end

  describe "GenServer.call timeout during stream consumption" do
    test "dispatches :failed (not :crashed) when provider stalls and call timeout fires" do
      runtime = start_runtime!()
      agent = test_agent(%StreamTimeoutLLM{})

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-timeout", agent, "Hello", default_opts())

      await_exit(pid)

      assert_receive {:test_event, "task-timeout", {:failed, {:error, reason, _loop_id}},
                      _metadata}

      assert reason == :genserver_call_timeout

      refute_receive {:test_event, "task-timeout", {:crashed, _}, _}, 100
      refute SwarmAi.Runtime.running?(runtime, "task-timeout")
    end
  end

  describe "death watcher" do
    test "dispatches :terminated on :shutdown exit" do
      runtime = start_runtime!()

      agent = test_agent(%MockLLM{response: fn -> exit(:shutdown) end})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-shut", agent, "Hello", default_opts())
      await_exit(pid)

      assert_receive {:test_event, "task-shut", {:terminated, %{loop: _}}, _metadata}, 200
      refute_receive {:test_event, "task-shut", {:crashed, _}, _}, 0
      refute_receive {:test_event, "task-shut", {:cancelled, _}, _}, 0
    end

    test "dispatches :terminated on {:shutdown, reason} exit" do
      runtime = start_runtime!()

      agent = test_agent(%MockLLM{response: fn -> exit({:shutdown, :supervisor_restart}) end})

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-shut-tuple", agent, "Hello", default_opts())

      await_exit(pid)

      assert_receive {:test_event, "task-shut-tuple", {:terminated, %{loop: _}}, _metadata}, 200
      refute_receive {:test_event, "task-shut-tuple", {:crashed, _}, _}, 0
    end

    test ":terminated event includes loop snapshot" do
      runtime = start_runtime!()

      {:ok, call_count} = Agent.start_link(fn -> 0 end)

      agent =
        test_agent(%MockLLM{
          response: fn ->
            count = Agent.get_and_update(call_count, fn c -> {c, c + 1} end)

            if count == 0 do
              {:ok,
               %SwarmAi.LLM.Response{
                 content: nil,
                 tool_calls: [
                   %SwarmAi.ToolCall{id: "tc1", name: "test_tool", arguments: %{}}
                 ],
                 usage: %SwarmAi.LLM.Usage{input_tokens: 10, output_tokens: 5},
                 raw: nil
               }}
            else
              exit(:shutdown)
            end
          end
        })

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-shut-snap", agent, "Hello", default_opts())

      await_exit(pid)

      assert_receive {:test_event, "task-shut-snap", {:terminated, %{loop: loop}}, _metadata}
      assert loop != nil
    end

    test "silent on :normal exit — no event dispatched" do
      runtime = start_runtime!()

      agent = test_agent(%MockLLM{response: fn -> exit(:normal) end})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-norm", agent, "Hello", default_opts())
      await_exit(pid)

      refute_receive {:test_event, "task-norm", {:terminated, _}, _}, 200
      refute_receive {:test_event, "task-norm", {:crashed, _}, _}, 0
      refute_receive {:test_event, "task-norm", {:cancelled, _}, _}, 0
      refute_receive {:test_event, "task-norm", {:completed, _}, _}, 0
    end

    test "crash event includes loop snapshot from last response" do
      runtime = start_runtime!()

      # Stateful LLM: first call returns a tool call (triggers on_response),
      # second call crashes — so the watcher holds the snapshot from iteration 1.
      {:ok, call_count} = Agent.start_link(fn -> 0 end)

      agent =
        test_agent(%MockLLM{
          response: fn ->
            count = Agent.get_and_update(call_count, fn c -> {c, c + 1} end)

            if count == 0 do
              {:ok,
               %SwarmAi.LLM.Response{
                 content: nil,
                 tool_calls: [
                   %SwarmAi.ToolCall{id: "tc1", name: "test_tool", arguments: %{}}
                 ],
                 usage: %SwarmAi.LLM.Usage{input_tokens: 10, output_tokens: 5},
                 raw: nil
               }}
            else
              exit(:boom_after_snapshot)
            end
          end
        })

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-snap", agent, "Hello", default_opts())

      await_exit(pid)

      assert_receive {:test_event, "task-snap", {:crashed, %{loop: loop}}, _metadata}
      assert loop != nil
    end

    test "crash event has nil loop when no response received" do
      runtime = start_runtime!()

      # Use an agent that exits immediately without any streaming
      agent = test_agent(%MockLLM{response: fn -> exit(:kaboom) end})

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-nosnap", agent, "Hello", default_opts())

      await_exit(pid)

      assert_receive {:test_event, "task-nosnap", {:crashed, %{loop: nil}}, _metadata}
    end

    test "dispatch failure during crash does not prevent cleanup" do
      runtime = start_runtime!(dispatcher: :failing)

      agent = test_agent(%MockLLM{response: fn -> exit(:kaboom) end})

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-fail-disp", agent, "Hello", default_opts())

      await_exit(pid)

      # The task's `after` block unregisters before the process exits,
      # so running?/2 returns false by the time await_exit completes.
      refute SwarmAi.Runtime.running?(runtime, "task-fail-disp")
    end
  end

  describe "pause_agent" do
    test "pause_agent tool timeout returns :paused result, no :failed event" do
      runtime = start_runtime!()

      # Executor returns Sync executions with 10ms timeout and :pause_agent policy.
      pause_executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          %ToolExecution.Sync{
            tool_call: tc,
            timeout_ms: 10,
            on_timeout_policy: :pause_agent,
            run: {__MODULE__, :slow_run, []},
            on_timeout: {__MODULE__, :noop_timeout, []}
          }
        end)
      end

      llm = %SwarmAi.Testing.MockLLM{
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

      agent = test_agent(llm)

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-pause", agent, "Hello",
          tool_executor: pause_executor
        )

      await_exit(pid)

      # Agent should not dispatch :completed or :failed — it paused
      refute_receive {:test_event, "task-pause", {:completed, _}, _}, 200
      refute_receive {:test_event, "task-pause", {:failed, _}, _}, 0
      refute_receive {:test_event, "task-pause", {:crashed, _}, _}, 0
      refute SwarmAi.Runtime.running?(runtime, "task-pause")
    end
  end

  describe "streaming events" do
    test "dispatches chunk and response events" do
      runtime = start_runtime!()
      agent = test_agent(mock_llm("Hi"))

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-s", agent, "Hello", default_opts())
      await_exit(pid)

      assert_receive {:test_event, "task-s", {:chunk, _}, _metadata}
      assert_receive {:test_event, "task-s", {:response, _}, _metadata}
    end
  end

  # --- Test Dispatchers ---

  defmodule TestDispatcher do
    def dispatch(test_pid, key, event, metadata) do
      send(test_pid, {:test_event, key, event, metadata})
    end
  end

  defmodule FailingDispatcher do
    def dispatch(_test_pid, _key, _event, _metadata), do: raise("dispatch exploded")
  end

  # --- Helpers ---

  defp start_runtime!(opts \\ []) do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    test_pid = self()

    dispatcher =
      case Keyword.get(opts, :dispatcher, :default) do
        :failing -> {__MODULE__.FailingDispatcher, :dispatch, [test_pid]}
        :default -> {__MODULE__.TestDispatcher, :dispatch, [test_pid]}
      end

    start_supervised!({SwarmAi.Runtime, name: name, event_dispatcher: dispatcher})

    name
  end

  defp default_opts(extra \\ []) do
    Keyword.merge(
      [
        tool_executor: fn tool_calls ->
          Enum.map(tool_calls, fn tc ->
            %ToolExecution.Sync{
              tool_call: tc,
              timeout_ms: 5_000,
              on_timeout_policy: :error,
              run: {__MODULE__, :instant_run, []},
              on_timeout: {__MODULE__, :noop_timeout, []}
            }
          end)
        end
      ],
      extra
    )
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 2000
  end
end
