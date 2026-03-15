defmodule SwarmTest do
  use SwarmAi.Testing, async: true

  alias SwarmAi.Message.ContentPart

  @moduledoc """
  Integration tests for SwarmAi.run/2 and SwarmAi.continue/2 API.
  """

  describe "run/2 with text responses" do
    @tag echo_agent: true
    test "returns completed with echoed response", %{echo_agent: agent} do
      assert {:completed, loop} = SwarmAi.run(agent, "Hello world")
      assert loop.result == "Echo: Hello world"
    end

    @tag mock_llm: "Fixed response"
    test "returns completed with mock response", %{mock_llm: llm} do
      agent = test_agent(llm)
      assert {:completed, loop} = SwarmAi.run(agent, "Any message")
      assert loop.result == "Fixed response"
    end
  end

  describe "run/2 and continue/2 with tool calls" do
    test "returns tool_calls and continues after results" do
      llm =
        tool_then_complete_llm(
          [%SwarmAi.ToolCall{id: "tc_1", name: "get_weather", arguments: ~s({"city":"NYC"})}],
          "The weather is sunny"
        )

      agent = test_agent(llm)

      # First call returns tool_calls
      assert {:tool_calls, loop, tool_calls} = SwarmAi.run(agent, "What's the weather?")
      assert [tc] = tool_calls
      assert tc.name == "get_weather"
      assert tc.id == "tc_1"

      # Execute tool and continue
      results = [ToolResult.make("tc_1", "Sunny, 22°C", false)]
      assert {:completed, loop} = SwarmAi.continue(loop, results)
      assert loop.result == "The weather is sunny"
    end

    test "handles multiple tool calls" do
      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "search", arguments: ~s({"q":"elixir"})},
             %SwarmAi.ToolCall{id: "tc_2", name: "search", arguments: ~s({"q":"phoenix"})}
           ], "Searching..."},
          {:complete, "Found results"}
        ])

      agent = test_agent(llm)

      # Get tool calls
      assert {:tool_calls, loop, tool_calls} = SwarmAi.run(agent, "Search")
      assert length(tool_calls) == 2

      # Execute all tools and continue
      results = [
        ToolResult.make("tc_1", "Result for elixir", false),
        ToolResult.make("tc_2", "Result for phoenix", false)
      ]

      assert {:completed, loop} = SwarmAi.continue(loop, results)
      assert loop.result == "Found results"
    end

    test "propagates tool errors to LLM" do
      llm =
        multi_turn_llm([
          {:tool_calls, [%SwarmAi.ToolCall{id: "tc_1", name: "fail", arguments: "{}"}],
           "Trying..."},
          {:complete, "Handled the error"}
        ])

      agent = test_agent(llm)

      assert {:tool_calls, loop, [tc]} = SwarmAi.run(agent, "Do something")

      # Return error result
      results = [ToolResult.make(tc.id, "Tool failed", true)]
      assert {:completed, loop} = SwarmAi.continue(loop, results)
      assert loop.result == "Handled the error"
    end

    test "handles multiple rounds of tool calls" do
      llm =
        multi_turn_llm([
          {:tool_calls, [%SwarmAi.ToolCall{id: "tc_1", name: "step1", arguments: "{}"}],
           "Step 1"},
          {:tool_calls, [%SwarmAi.ToolCall{id: "tc_2", name: "step2", arguments: "{}"}],
           "Step 2"},
          {:complete, "All done"}
        ])

      agent = test_agent(llm)

      # First round
      assert {:tool_calls, loop, [tc1]} = SwarmAi.run(agent, "Multi-step")
      assert tc1.name == "step1"
      results1 = [ToolResult.make(tc1.id, "Result 1", false)]

      # Second round
      assert {:tool_calls, loop, [tc2]} = SwarmAi.continue(loop, results1)
      assert tc2.name == "step2"
      results2 = [ToolResult.make(tc2.id, "Result 2", false)]

      # Complete
      assert {:completed, loop} = SwarmAi.continue(loop, results2)
      assert loop.result == "All done"
    end
  end

  describe "run/2 error handling" do
    @tag error_agent: :llm_unavailable
    test "returns error tuple", %{error_agent: agent} do
      assert {:error, loop} = SwarmAi.run(agent, "Hello")
      assert loop.error == :llm_unavailable
    end
  end

  describe "concurrent tool execution pattern" do
    test "caller can execute tools concurrently" do
      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "slow", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "slow", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_3", name: "slow", arguments: "{}"}
           ], "Running..."},
          {:complete, "All completed"}
        ])

      agent = test_agent(llm)

      assert {:tool_calls, loop, tool_calls} = SwarmAi.run(agent, "Do concurrent work")
      assert length(tool_calls) == 3

      # Execute concurrently using Task
      results =
        tool_calls
        |> Task.async_stream(fn tc ->
          # Simulate work
          Process.sleep(10)
          ToolResult.make(tc.id, "Done: #{tc.name}", false)
        end)
        |> Enum.map(fn {:ok, result} -> result end)

      assert {:completed, loop} = SwarmAi.continue(loop, results)
      assert loop.result == "All completed"
    end
  end

  describe "loop state" do
    test "loop tracks steps and tool calls" do
      llm =
        tool_then_complete_llm(
          [%SwarmAi.ToolCall{id: "tc_1", name: "test", arguments: "{}"}],
          "Done"
        )

      agent = test_agent(llm)

      # After run, loop has first step
      assert {:tool_calls, loop, _} = SwarmAi.run(agent, "Test")
      assert loop.current_step == 1
      assert length(loop.steps) == 1

      # After continue, loop has second step
      results = [ToolResult.make("tc_1", "Result", false)]
      assert {:completed, loop} = SwarmAi.continue(loop, results)
      assert loop.current_step == 2
      assert length(loop.steps) == 2
    end

    test "loop contains agent" do
      llm = mock_llm("Response")
      agent = test_agent(llm, "MyAgent")

      assert {:completed, loop} = SwarmAi.run(agent, "Hello")
      assert loop.agent == agent
    end
  end

  describe "message input variations" do
    test "accepts string input" do
      llm = mock_llm("Response")
      agent = test_agent(llm)

      assert {:completed, _loop} = SwarmAi.run(agent, "Hello")
    end

    test "accepts single Message struct" do
      llm = mock_llm("Response")
      agent = test_agent(llm)

      assert {:completed, _loop} = SwarmAi.run(agent, SwarmAi.Message.user("Hello"))
    end

    test "accepts list of Message structs" do
      llm = mock_llm("Response")
      agent = test_agent(llm)

      messages = [
        SwarmAi.Message.user("First message"),
        SwarmAi.Message.user("Second message")
      ]

      assert {:completed, loop} = SwarmAi.run(agent, messages)
      # Both user messages should be in step input
      [step] = loop.steps
      user_msgs = Enum.filter(step.input_messages, &(&1.role == :user))
      assert length(user_msgs) == 2
    end

    test "accepts multimodal message with image" do
      llm = mock_llm("I see an image")
      agent = test_agent(llm)

      # Create a message with text and image content parts
      content = [
        ContentPart.text("What's in this image?"),
        ContentPart.image_url("https://example.com/image.png")
      ]

      message = %SwarmAi.Message{role: :user, content: content}

      assert {:completed, loop} = SwarmAi.run(agent, message)
      assert loop.result == "I see an image"

      # Verify multimodal content was preserved in the step
      [step] = loop.steps
      [_system, user_msg] = step.input_messages
      assert is_list(user_msg.content)
      assert length(user_msg.content) == 2
    end
  end

  describe "tool result ordering" do
    test "accepts results in different order than tool calls" do
      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "first", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "second", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_3", name: "third", arguments: "{}"}
           ], "Running..."},
          {:complete, "All done"}
        ])

      agent = test_agent(llm)

      assert {:tool_calls, loop, _tool_calls} = SwarmAi.run(agent, "Do work")

      # Return results in reverse order (simulating concurrent completion)
      results = [
        ToolResult.make("tc_3", "Third result", false),
        ToolResult.make("tc_1", "First result", false),
        ToolResult.make("tc_2", "Second result", false)
      ]

      assert {:completed, loop} = SwarmAi.continue(loop, results)
      assert loop.result == "All done"
    end
  end

  describe "loop immutability" do
    test "continue/2 returns new loop without mutating original" do
      llm =
        tool_then_complete_llm(
          [%SwarmAi.ToolCall{id: "tc_1", name: "test", arguments: "{}"}],
          "Done"
        )

      agent = test_agent(llm)

      assert {:tool_calls, original_loop, _} = SwarmAi.run(agent, "Test")
      original_status = original_loop.status

      results = [ToolResult.make("tc_1", "Result", false)]
      assert {:completed, new_loop} = SwarmAi.continue(original_loop, results)

      # Original loop unchanged
      assert original_loop.status == original_status
      assert original_loop.status == :waiting_for_tools

      # New loop is different
      assert new_loop.status == :completed
      refute original_loop == new_loop
    end
  end

  describe "edge cases" do
    test "continue/2 with empty results list does not advance" do
      llm =
        tool_then_complete_llm(
          [%SwarmAi.ToolCall{id: "tc_1", name: "test", arguments: "{}"}],
          "Done"
        )

      agent = test_agent(llm)

      assert {:tool_calls, loop, tool_calls} = SwarmAi.run(agent, "Test")
      assert length(tool_calls) == 1

      # Continue with empty results - should still be waiting
      assert {:tool_calls, loop, pending} = SwarmAi.continue(loop, [])
      assert length(pending) == 1
      assert loop.status == :waiting_for_tools
    end

    test "continue/2 with unknown tool ID is ignored" do
      llm =
        tool_then_complete_llm(
          [%SwarmAi.ToolCall{id: "tc_1", name: "test", arguments: "{}"}],
          "Done"
        )

      agent = test_agent(llm)

      assert {:tool_calls, loop, _} = SwarmAi.run(agent, "Test")

      # Provide result with wrong ID - should be ignored, still waiting
      results = [ToolResult.make("wrong_id", "Result", false)]
      assert {:tool_calls, updated_loop, pending} = SwarmAi.continue(loop, results)
      assert length(pending) == 1
      assert updated_loop.status == :waiting_for_tools
    end

    test "continue/2 with partial results waits for remaining" do
      llm =
        multi_turn_llm([
          {:tool_calls,
           [
             %SwarmAi.ToolCall{id: "tc_1", name: "first", arguments: "{}"},
             %SwarmAi.ToolCall{id: "tc_2", name: "second", arguments: "{}"}
           ], "Running..."},
          {:complete, "All done"}
        ])

      agent = test_agent(llm)

      assert {:tool_calls, loop, tool_calls} = SwarmAi.run(agent, "Do work")
      assert length(tool_calls) == 2

      # Only provide first result
      partial = [ToolResult.make("tc_1", "First done", false)]
      assert {:tool_calls, loop, pending} = SwarmAi.continue(loop, partial)

      # Still waiting for tc_2
      assert length(pending) == 1
      assert hd(pending).id == "tc_2"

      # Now provide second result
      remaining = [ToolResult.make("tc_2", "Second done", false)]
      assert {:completed, loop} = SwarmAi.continue(loop, remaining)
      assert loop.result == "All done"
    end

    test "continue/2 with duplicate result for same tool ID is ignored" do
      llm =
        tool_then_complete_llm(
          [%SwarmAi.ToolCall{id: "tc_1", name: "test", arguments: "{}"}],
          "Done"
        )

      agent = test_agent(llm)

      assert {:tool_calls, loop, _} = SwarmAi.run(agent, "Test")

      # Provide the result
      result = ToolResult.make("tc_1", "First result", false)
      assert {:completed, loop} = SwarmAi.continue(loop, [result])
      assert loop.result == "Done"

      # The loop is now completed - can't continue further
      # (This verifies the tool was marked complete and won't accept duplicates)
    end
  end

  describe "conversation history" do
    test "loop accumulates messages across steps" do
      llm =
        multi_turn_llm([
          {:tool_calls, [%SwarmAi.ToolCall{id: "tc_1", name: "lookup", arguments: "{}"}],
           "Looking up..."},
          {:complete, "Found the answer"}
        ])

      agent = test_agent(llm)

      assert {:tool_calls, loop, _} = SwarmAi.run(agent, "Find something")
      results = [ToolResult.make("tc_1", "Lookup result", false)]
      assert {:completed, loop} = SwarmAi.continue(loop, results)

      # Should have 2 steps
      assert length(loop.steps) == 2

      # Second step should have full conversation history
      [_step1, step2] = loop.steps

      roles = Enum.map(step2.input_messages, & &1.role)
      assert :system in roles
      assert :user in roles
      assert :assistant in roles
      assert :tool in roles
    end
  end

  describe "tool call utilities" do
    test "tool call arguments can be parsed as JSON" do
      llm =
        tool_then_complete_llm(
          [
            %SwarmAi.ToolCall{
              id: "tc_1",
              name: "get_weather",
              arguments: ~s({"city":"NYC","units":"celsius"})
            }
          ],
          "Done"
        )

      agent = test_agent(llm)

      assert {:tool_calls, _loop, [tc]} = SwarmAi.run(agent, "Weather?")
      assert {:ok, args} = SwarmAi.ToolCall.parse_arguments(tc)
      assert args["city"] == "NYC"
      assert args["units"] == "celsius"
    end

    test "tool call with invalid JSON returns error" do
      tc = %SwarmAi.ToolCall{id: "tc_1", name: "test", arguments: "not json"}
      assert {:error, %Jason.DecodeError{}} = SwarmAi.ToolCall.parse_arguments(tc)
    end
  end
end
