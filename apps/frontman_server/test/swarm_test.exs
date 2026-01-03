defmodule SwarmTest do
  use FrontmanServer.SwarmCase, async: true

  @moduledoc """
  Integration tests for Swarm.run/4 synchronous execution API.
  """

  describe "run/4 with text responses" do
    @tag echo_agent: true
    test "returns echoed response", %{echo_agent: agent} do
      result = Swarm.run(agent, "Hello world", %{tool_handler: fn _ -> {:ok, ""} end})

      assert {:ok, "Echo: Hello world"} = result
    end

    @tag mock_llm: "Fixed response"
    test "returns mock response", %{mock_llm: llm} do
      agent = test_agent(llm)
      result = Swarm.run(agent, "Any message", %{tool_handler: fn _ -> {:ok, ""} end})

      assert {:ok, "Fixed response"} = result
    end
  end

  describe "run/4 with tool calls" do
    test "executes tool and returns final response" do
      llm = tool_then_complete_llm(
        [%Swarm.ToolCall{id: "tc_1", name: "get_weather", arguments: %{"city" => "NYC"}}],
        "The weather is sunny"
      )

      agent = test_agent(llm)
      tool_handler = fn tc ->
        assert tc.name == "get_weather"
        assert tc.arguments["city"] == "NYC"
        {:ok, "Sunny, 22°C"}
      end

      assert {:ok, "The weather is sunny"} = Swarm.run(agent, "What's the weather?", %{tool_handler: tool_handler})
    end

    test "handles multiple tool calls in sequence" do
      llm = multi_turn_llm([
        {:tool_calls, [
          %Swarm.ToolCall{id: "tc_1", name: "search", arguments: %{"q" => "elixir"}},
          %Swarm.ToolCall{id: "tc_2", name: "search", arguments: %{"q" => "phoenix"}}
        ], "Searching..."},
        {:complete, "Found results"}
      ])

      agent = test_agent(llm)
      calls = :ets.new(:calls, [:set, :public])

      tool_handler = fn tc ->
        :ets.insert(calls, {tc.id, tc.arguments["q"]})
        {:ok, "Result for #{tc.arguments["q"]}"}
      end

      assert {:ok, "Found results"} = Swarm.run(agent, "Search", %{tool_handler: tool_handler})
      assert [{"tc_1", "elixir"}, {"tc_2", "phoenix"}] = :ets.tab2list(calls) |> Enum.sort()
    end

    test "propagates tool errors to LLM" do
      llm = multi_turn_llm([
        {:tool_calls, [%Swarm.ToolCall{id: "tc_1", name: "fail", arguments: %{}}], "Trying..."},
        {:complete, "Handled the error"}
      ])

      agent = test_agent(llm)
      tool_handler = fn _ -> {:error, "Tool failed"} end

      assert {:ok, "Handled the error"} = Swarm.run(agent, "Do something", %{tool_handler: tool_handler})
    end
  end

  describe "run/4 with async tool results (blocking pattern)" do
    test "tool_handler blocks until external result arrives" do
      llm = tool_then_complete_llm(
        [%Swarm.ToolCall{id: "tc_async", name: "external_call", arguments: %{}}],
        "Got async result"
      )

      agent = test_agent(llm)
      test_pid = self()

      # Simulate async tool execution: tool_handler blocks,
      # external process delivers result
      tool_handler = fn tc ->
        ref = make_ref()

        # Spawn "external system" that delivers result after delay
        spawn(fn ->
          Process.sleep(50)
          send(test_pid, {:tool_result, ref, "Async result from external system"})
        end)

        # Block waiting for result (like AgentRunner will do)
        receive do
          {:tool_result, ^ref, content} -> {:ok, content}
        after
          5_000 -> {:error, "Timeout waiting for #{tc.id}"}
        end
      end

      assert {:ok, "Got async result"} = Swarm.run(agent, "Call external", %{tool_handler: tool_handler})
    end

    test "tool_handler timeout returns error to LLM" do
      llm = multi_turn_llm([
        {:tool_calls, [%Swarm.ToolCall{id: "tc_timeout", name: "slow_tool", arguments: %{}}], "Calling..."},
        {:complete, "Handled timeout"}
      ])

      agent = test_agent(llm)

      tool_handler = fn tc ->
        receive do
          {:result, content} -> {:ok, content}
        after
          10 -> {:error, "Timeout: #{tc.name}"}
        end
      end

      assert {:ok, "Handled timeout"} = Swarm.run(agent, "Do slow thing", %{tool_handler: tool_handler})
    end
  end

  describe "run/4 error handling" do
    @tag error_agent: :llm_unavailable
    test "returns LLM errors", %{error_agent: agent} do
      result = Swarm.run(agent, "Hello", %{tool_handler: fn _ -> {:ok, ""} end})

      assert {:error, :llm_unavailable} = result
    end

    test "enforces max_steps limit" do
      # LLM that always returns tool calls, never completes
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      llm = mock_llm(fn ->
        n = Agent.get_and_update(counter, fn n -> {n, n + 1} end)
        {:ok, %LLM.Response{
          content: "Step #{n}",
          tool_calls: [%Swarm.ToolCall{id: "tc_#{n}", name: "loop", arguments: %{}}],
          usage: %{input_tokens: 1, output_tokens: 1},
          raw: nil
        }}
      end)

      agent = test_agent(llm)
      result = Swarm.run(agent, "Loop", %{tool_handler: fn _ -> {:ok, "ok"} end}, max_steps: 3)

      assert {:error, {:max_steps_exceeded, 3}} = result
    end
  end

  describe "run/4 with on_chunk callback" do
    test "receives chunks during streaming" do
      llm = mock_llm("Hello world")
      agent = test_agent(llm)
      test_pid = self()

      callbacks = %{
        tool_handler: fn _ -> {:ok, ""} end,
        on_chunk: fn chunk -> send(test_pid, {:chunk, chunk}) end
      }

      assert {:ok, "Hello world"} = Swarm.run(agent, "Hello", callbacks)

      assert_received {:chunk, %{type: :token, text: "Hello world"}}
      assert_received {:chunk, %{type: :usage}}
      assert_received {:chunk, %{type: :done}}
    end

    test "on_chunk is optional" do
      llm = mock_llm("Response without callback")
      agent = test_agent(llm)

      callbacks = %{tool_handler: fn _ -> {:ok, ""} end}

      assert {:ok, "Response without callback"} = Swarm.run(agent, "Hello", callbacks)
    end
  end
end
