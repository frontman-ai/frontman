defmodule SwarmAi.RuntimeTest do
  use SwarmAi.Testing, async: true

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
      assert_receive {:test_event, "task-complete", {:completed, {:ok, "Echo: Hello", _loop_id}}}

      refute SwarmAi.Runtime.running?(runtime, "task-complete")
    end

    test "dispatches completed event with metadata passed to dispatcher" do
      runtime = start_runtime_with_metadata_dispatch!()
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

      assert_receive {:test_event_with_meta, "task-meta",
                      {:completed, {:ok, "Echo: Hello", _loop_id}}, metadata}

      assert metadata.my_key == "my_val"
    end

    test "dispatches failed event on LLM error" do
      runtime = start_runtime!()
      agent = test_agent(%ErrorLLM{error: :llm_api_failure})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-error", agent, "Hello", default_opts())

      await_exit(pid)

      assert_receive {:test_event, "task-error", {:failed, {:error, _reason, _loop_id}}}
    end

    test "prevents duplicate execution for same key" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 500})

      {:ok, _} = SwarmAi.Runtime.run(runtime, "task-dup", agent, "Hello", default_opts())

      assert SwarmAi.Runtime.run(runtime, "task-dup", agent, "World", default_opts()) ==
               {:error, :already_running}
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
    test "dispatches cancelled (not crashed) and unregisters" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 5000})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-c", agent, "Hello", default_opts())

      assert SwarmAi.Runtime.cancel(runtime, "task-c") == :ok
      await_exit(pid)

      assert_receive {:test_event, "task-c", {:cancelled, _}}
      refute_receive {:test_event, "task-c", {:crashed, _}}, 100
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
      assert_receive {:test_event, "task-crash", {:failed, {:error, reason, _loop_id}}}
      assert %RuntimeError{message: "boom"} = reason
      refute SwarmAi.Runtime.running?(runtime, "task-crash")
    end

    test "dispatches crashed with {reason, []} for non-exception exits" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: fn -> exit(:kaboom) end})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-exit", agent, "Hello", default_opts())
      await_exit(pid)

      assert_receive {:test_event, "task-exit", {:crashed, %{reason: :kaboom, stacktrace: []}}}
    end
  end

  describe "GenServer.call timeout during stream consumption" do
    test "dispatches :failed (not :crashed) when provider stalls and call timeout fires" do
      runtime = start_runtime!()
      agent = test_agent(%StreamTimeoutLLM{})

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-timeout", agent, "Hello", default_opts())

      await_exit(pid)

      assert_receive {:test_event, "task-timeout",
                      {:failed, {:error, reason, _loop_id}}}

      assert reason == :genserver_call_timeout

      refute_receive {:test_event, "task-timeout", {:crashed, _}}, 100
      refute SwarmAi.Runtime.running?(runtime, "task-timeout")
    end
  end

  describe "death watcher" do
    test "silent on :shutdown exit — no event dispatched" do
      runtime = start_runtime!()

      agent = test_agent(%MockLLM{response: fn -> exit(:shutdown) end})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-shut", agent, "Hello", default_opts())
      await_exit(pid)

      refute_receive {:test_event, "task-shut", {:crashed, _}}, 200
      refute_receive {:test_event, "task-shut", {:cancelled, _}}, 0
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

      assert_receive {:test_event, "task-snap", {:crashed, %{loop: loop}}}
      assert loop != nil
    end

    test "crash event has nil loop when no response received" do
      runtime = start_runtime!()

      # Use an agent that exits immediately without any streaming
      agent = test_agent(%MockLLM{response: fn -> exit(:kaboom) end})

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-nosnap", agent, "Hello", default_opts())

      await_exit(pid)

      assert_receive {:test_event, "task-nosnap", {:crashed, %{loop: nil}}}
    end

    test "dispatch failure during crash does not prevent cleanup" do
      runtime = start_runtime_with_failing_dispatch!()

      agent = test_agent(%MockLLM{response: fn -> exit(:kaboom) end})

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-fail-disp", agent, "Hello", default_opts())

      await_exit(pid)

      # The task's `after` block unregisters before the process exits,
      # so running?/2 returns false by the time await_exit completes.
      refute SwarmAi.Runtime.running?(runtime, "task-fail-disp")
    end
  end

  describe "streaming events" do
    test "dispatches chunk and response events" do
      runtime = start_runtime!()
      agent = test_agent(mock_llm("Hi"))

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-s", agent, "Hello", default_opts())
      await_exit(pid)

      assert_receive {:test_event, "task-s", {:chunk, _}}
      assert_receive {:test_event, "task-s", {:response, _}}
    end
  end

  # --- Test Dispatchers ---

  defmodule TestDispatcher do
    def dispatch(test_pid, key, event, _metadata) do
      send(test_pid, {:test_event, key, event})
    end
  end

  defmodule MetadataTestDispatcher do
    def dispatch(test_pid, key, event, metadata) do
      send(test_pid, {:test_event_with_meta, key, event, metadata})
    end
  end

  defmodule FailingDispatcher do
    def dispatch(_key, _event, _metadata), do: raise("dispatch exploded")
  end

  # --- Helpers ---

  defp start_runtime! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    test_pid = self()

    start_supervised!(
      {SwarmAi.Runtime,
       name: name, event_dispatcher: {__MODULE__.TestDispatcher, :dispatch, [test_pid]}}
    )

    name
  end

  defp start_runtime_with_failing_dispatch! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"

    start_supervised!(
      {SwarmAi.Runtime,
       name: name, event_dispatcher: {__MODULE__.FailingDispatcher, :dispatch, []}}
    )

    name
  end

  defp start_runtime_with_metadata_dispatch! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    test_pid = self()

    start_supervised!(
      {SwarmAi.Runtime,
       name: name, event_dispatcher: {__MODULE__.MetadataTestDispatcher, :dispatch, [test_pid]}}
    )

    name
  end

  defp default_opts(extra \\ []) do
    Keyword.merge(
      [
        tool_executor: fn tool_calls ->
          Enum.map(tool_calls, fn tc -> ToolResult.make(tc.id, "done", false) end)
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
