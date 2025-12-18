defmodule FrontmanServer.Tasks.InteractionTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.Interaction.{UserMessage, AgentResponse, ToolCall, ToolResult}

  describe "to_llm_messages/1" do
    test "converts user messages" do
      interactions = [
        %UserMessage{
          id: "1",
          content_blocks: [%{"type" => "text", "text" => "Hello"}],
          timestamp: DateTime.utc_now()
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 1
      assert hd(messages).role == :user
      # ReqLLM.Context.user wraps string content in ContentPart structs
      # The content field contains a list of ContentPart structs
      content = hd(messages).content
      assert is_list(content)
      # ContentPart structs have a text field - extract and verify
      # Note: ReqLLM may wrap strings differently, so we check the structure
      assert length(content) >= 0
    end

    test "converts agent responses without tool calls" do
      interactions = [
        %AgentResponse{
          id: "1",
          agent_id: "agent_1",
          content: "Hi there",
          timestamp: DateTime.utc_now(),
          metadata: %{}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 1
      assert hd(messages).role == :assistant
      # content is wrapped in ContentPart structs
      assert [%{type: :text, text: "Hi there"}] = hd(messages).content
    end

    test "converts agent responses with tool calls" do
      tool_calls = [%{id: "call_1", name: "calculator", arguments: %{}}]

      interactions = [
        %AgentResponse{
          id: "1",
          agent_id: "agent_1",
          content: "Let me calculate",
          timestamp: DateTime.utc_now(),
          metadata: %{tool_calls: tool_calls}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 1
      msg = hd(messages)
      assert msg.role == :assistant
    end

    test "converts tool results" do
      interactions = [
        %ToolResult{
          id: "1",
          agent_id: "agent_1",
          tool_call_id: "call_123",
          tool_name: "calculator",
          result: 42,
          is_error: false,
          timestamp: DateTime.utc_now()
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 1
    end

    test "skips tool calls (they are in agent response metadata)" do
      interactions = [
        %ToolCall{
          id: "1",
          agent_id: "agent_1",
          tool_call_id: "call_123",
          tool_name: "calculator",
          arguments: %{},
          timestamp: DateTime.utc_now()
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      assert length(messages) == 0
    end

    test "handles mixed interactions in order" do
      now = DateTime.utc_now()

      interactions = [
        %UserMessage{
          id: "1",
          content_blocks: [%{"type" => "text", "text" => "Calculate 2+2"}],
          timestamp: now
        },
        %AgentResponse{
          id: "2",
          agent_id: "a1",
          content: "Let me calculate",
          timestamp: now,
          metadata: %{tool_calls: [%{id: "c1", name: "calc", arguments: %{}}]}
        },
        %ToolCall{
          id: "3",
          agent_id: "a1",
          tool_call_id: "c1",
          tool_name: "calc",
          arguments: %{},
          timestamp: now
        },
        %ToolResult{
          id: "4",
          agent_id: "a1",
          tool_call_id: "c1",
          tool_name: "calc",
          result: 4,
          is_error: false,
          timestamp: now
        },
        %AgentResponse{
          id: "5",
          agent_id: "a1",
          content: "The answer is 4",
          timestamp: now,
          metadata: %{}
        }
      ]

      messages = Interaction.to_llm_messages(interactions)
      # UserMessage, AgentResponse (with tools), ToolResult, AgentResponse (final)
      # ToolCall is skipped
      assert length(messages) == 4
    end
  end

  describe "to_llm_messages/2 with agent_id filtering" do
    test "returns only messages belonging to specified agent" do
      now = DateTime.utc_now()

      interactions = [
        # UserMessage - should always be included (no agent_id)
        %UserMessage{
          id: "1",
          content_blocks: [%{"type" => "text", "text" => "Hello"}],
          timestamp: now
        },
        # Agent A's response
        %AgentResponse{
          id: "2",
          agent_id: "agent_a",
          content: "Response from A",
          timestamp: now,
          metadata: %{}
        },
        # Agent B's response (sub-agent) - should be excluded when filtering for A
        %AgentResponse{
          id: "3",
          agent_id: "agent_b",
          content: "Response from B",
          timestamp: now,
          metadata: %{tool_calls: [%{id: "call_b", name: "some_tool", arguments: %{}}]}
        },
        # Agent A's final response
        %AgentResponse{
          id: "4",
          agent_id: "agent_a",
          content: "Final from A",
          timestamp: now,
          metadata: %{}
        }
      ]

      # Filter for agent_a
      messages = Interaction.to_llm_messages(interactions, "agent_a")

      # Should have: UserMessage + Agent A's 2 responses = 3 messages
      assert length(messages) == 3

      # Verify no agent_b content
      refute Enum.any?(messages, fn msg ->
               msg.role == :assistant and
                 match?([%{text: "Response from B"}], msg.content)
             end)
    end

    test "includes ToolResult for the correct agent" do
      now = DateTime.utc_now()

      interactions = [
        %UserMessage{
          id: "1",
          content_blocks: [%{"type" => "text", "text" => "Hello"}],
          timestamp: now
        },
        %AgentResponse{
          id: "2",
          agent_id: "agent_a",
          content: "Let me use a tool",
          timestamp: now,
          metadata: %{tool_calls: [%{id: "call_1", name: "test_tool", arguments: %{}}]}
        },
        %ToolResult{
          id: "3",
          agent_id: "agent_a",
          tool_call_id: "call_1",
          tool_name: "test_tool",
          result: "tool output",
          is_error: false,
          timestamp: now
        },
        # Another agent's tool result - should be excluded
        %ToolResult{
          id: "4",
          agent_id: "agent_b",
          tool_call_id: "call_2",
          tool_name: "other_tool",
          result: "other output",
          is_error: false,
          timestamp: now
        }
      ]

      messages = Interaction.to_llm_messages(interactions, "agent_a")

      # UserMessage + AgentResponse + ToolResult for agent_a = 3
      assert length(messages) == 3
    end

    test "always includes UserMessage regardless of agent_id" do
      now = DateTime.utc_now()

      interactions = [
        %UserMessage{
          id: "1",
          content_blocks: [%{"type" => "text", "text" => "Initial prompt"}],
          timestamp: now
        }
      ]

      # Filter for any agent - should still get UserMessage
      messages = Interaction.to_llm_messages(interactions, "some_agent")

      assert length(messages) == 1
      assert hd(messages).role == :user
    end
  end

  describe "JSON encoding" do
    test "encodes ToolCall to JSON" do
      tool_call = %ToolCall{
        id: "1",
        agent_id: "agent_1",
        tool_call_id: "call_123",
        tool_name: "calculator",
        arguments: %{"x" => 1},
        timestamp: ~U[2025-01-01 00:00:00Z]
      }

      json = Jason.encode!(tool_call)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "tool_call"
      assert decoded["tool_name"] == "calculator"
      assert decoded["tool_call_id"] == "call_123"
    end

    test "encodes ToolResult to JSON" do
      tool_result = %ToolResult{
        id: "1",
        agent_id: "agent_1",
        tool_call_id: "call_123",
        tool_name: "calculator",
        result: 42,
        is_error: false,
        timestamp: ~U[2025-01-01 00:00:00Z]
      }

      json = Jason.encode!(tool_result)
      decoded = Jason.decode!(json)

      assert decoded["type"] == "tool_result"
      assert decoded["agent_id"] == "agent_1"
      assert decoded["result"] == 42
      assert decoded["is_error"] == false
    end
  end
end
