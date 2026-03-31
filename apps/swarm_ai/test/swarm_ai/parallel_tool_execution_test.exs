defmodule SwarmAi.ParallelToolExecutionTest do
  use SwarmAi.Testing, async: true

  describe "batch tool execution" do
    test "executes all tools via batch executor" do
      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "tool_a", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "tool_b", arguments: "{}"}
           ], "Running..."},
          {:complete, "Done"}
        ])

      agent = test_agent(llm)

      executor = fn tool_calls ->
        Enum.map(tool_calls, fn tc ->
          ToolResult.make(tc.id, "Result for #{tc.name}", false)
        end)
      end

      {:ok, result, _loop_id} =
        SwarmAi.run_streaming(agent, "Do work", tool_executor: executor)

      assert result == "Done"
    end

    test "parallel execution via Task.Supervisor" do
      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "slow", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "slow", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_3", name: "slow", arguments: "{}"}
           ], "Running..."},
          {:complete, "All done"}
        ])

      agent = test_agent(llm)
      {:ok, sup} = Task.Supervisor.start_link()

      executor = fn tool_calls ->
        sup
        |> Task.Supervisor.async_stream_nolink(tool_calls, fn tc ->
          Process.sleep(100)
          ToolResult.make(tc.id, "Result", false)
        end, max_concurrency: 10, ordered: true)
        |> Enum.zip(tool_calls)
        |> Enum.map(fn
          {{:ok, result}, _tc} -> result
          {{:exit, reason}, tc} ->
            ToolResult.make(tc.id, "Crashed: #{inspect(reason)}", true)
        end)
      end

      start = System.monotonic_time(:millisecond)

      {:ok, result, _loop_id} =
        SwarmAi.run_streaming(agent, "Do work", tool_executor: executor)

      elapsed = System.monotonic_time(:millisecond) - start

      assert result == "All done"
      assert elapsed < 250, "Expected parallel (<250ms) but took #{elapsed}ms"
    end

    test "fault isolation - crashing tool produces error result" do
      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "good", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "bad", arguments: "{}"}
           ], "Running..."},
          {:complete, "Handled"}
        ])

      agent = test_agent(llm)
      {:ok, sup} = Task.Supervisor.start_link()

      executor = fn tool_calls ->
        sup
        |> Task.Supervisor.async_stream_nolink(tool_calls, fn tc ->
          case tc.name do
            "bad" -> raise "boom"
            _ -> ToolResult.make(tc.id, "OK", false)
          end
        end, max_concurrency: 10, ordered: true)
        |> Enum.zip(tool_calls)
        |> Enum.map(fn
          {{:ok, result}, _tc} -> result
          {{:exit, reason}, tc} ->
            ToolResult.make(tc.id, "Crashed: #{inspect(reason)}", true)
        end)
      end

      {:ok, result, _loop_id} =
        SwarmAi.run_streaming(agent, "Do work", tool_executor: executor)

      assert result == "Handled"
    end

    test "run_blocking still works with single-tool executor" do
      llm =
        multi_turn_llm([
          {:tool_calls,
           [%SwarmAi.ToolCall{id: "tc_1", name: "test", arguments: "{}"}],
           "Running..."},
          {:complete, "Done"}
        ])

      agent = test_agent(llm)

      {:ok, result, _loop_id} =
        SwarmAi.run_blocking(agent, "Do work", fn _tc -> {:ok, "Result"} end)

      assert result == "Done"
    end
  end
end
