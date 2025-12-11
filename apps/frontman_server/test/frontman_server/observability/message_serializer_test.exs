defmodule FrontmanServer.Observability.MessageSerializerTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Observability.MessageSerializer

  describe "serialize_input/1" do
    test "serializes user message with string content" do
      msg = %{role: :user, content: "Hello, world!"}

      [result] = MessageSerializer.serialize_input([msg])

      assert result["role"] == "user"
      assert result["content"] == "Hello, world!"
    end

    test "serializes system message" do
      msg = %{role: :system, content: "You are helpful"}

      [result] = MessageSerializer.serialize_input([msg])

      assert result["role"] == "system"
      assert result["content"] == "You are helpful"
    end

    test "serializes assistant message" do
      msg = %{role: :assistant, content: "I can help with that."}

      [result] = MessageSerializer.serialize_input([msg])

      assert result["role"] == "assistant"
      assert result["content"] == "I can help with that."
    end

    test "serializes multiple messages" do
      messages = [
        %{role: :system, content: "You are helpful"},
        %{role: :user, content: "Hello"},
        %{role: :assistant, content: "Hi there!"}
      ]

      results = MessageSerializer.serialize_input(messages)

      assert length(results) == 3
      assert Enum.at(results, 0)["role"] == "system"
      assert Enum.at(results, 1)["role"] == "user"
      assert Enum.at(results, 2)["role"] == "assistant"
    end

    test "handles nil content" do
      msg = %{role: :user, content: nil}

      [result] = MessageSerializer.serialize_input([msg])

      assert result["content"] == ""
    end

    test "handles content as list of parts" do
      msg = %{
        role: :user,
        content: [
          %{type: :text, text: "First part"},
          %{type: :text, text: "Second part"}
        ]
      }

      [result] = MessageSerializer.serialize_input([msg])

      assert result["content"] == "First part\nSecond part"
    end
  end

  describe "serialize_output/2" do
    test "serializes response without tool calls" do
      [result] = MessageSerializer.serialize_output("Hello!", [])

      assert result["role"] == "assistant"
      assert result["content"] == "Hello!"
      refute Map.has_key?(result, "tool_calls")
    end

    test "serializes response with tool calls" do
      tool_call = %{
        id: "call_123",
        tool_name: "get_weather",
        arguments: %{"city" => "NYC"}
      }

      [result] = MessageSerializer.serialize_output("", [tool_call])

      assert result["role"] == "assistant"
      assert result["content"] == ""
      assert length(result["tool_calls"]) == 1

      tc = hd(result["tool_calls"])
      assert tc["id"] == "call_123"
      assert tc["type"] == "function"
      assert tc["function"]["name"] == "get_weather"
      assert tc["function"]["arguments"] == ~s({"city":"NYC"})
    end

    test "serializes response with multiple tool calls" do
      tool_calls = [
        %{id: "call_1", tool_name: "get_weather", arguments: %{"city" => "NYC"}},
        %{id: "call_2", tool_name: "get_time", arguments: %{"timezone" => "EST"}}
      ]

      [result] = MessageSerializer.serialize_output("Let me check...", tool_calls)

      assert result["content"] == "Let me check..."
      assert length(result["tool_calls"]) == 2
    end

    test "serializes ReqLLM.ToolCall structs" do
      tool_call = ReqLLM.ToolCall.new("call_abc", "read_file", ~s({"path":"./README.md"}))

      [result] = MessageSerializer.serialize_output("Reading file...", [tool_call])

      assert result["role"] == "assistant"
      assert result["content"] == "Reading file..."
      assert length(result["tool_calls"]) == 1

      tc = hd(result["tool_calls"])
      assert tc["id"] == "call_abc"
      assert tc["type"] == "function"
      assert tc["function"]["name"] == "read_file"
      assert tc["function"]["arguments"] == ~s({"path":"./README.md"})
    end
  end
end
