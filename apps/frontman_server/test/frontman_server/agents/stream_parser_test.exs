defmodule FrontmanServer.Agents.StreamParserTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents.StreamParser
  alias ReqLLM.ToolCall

  describe "tool_call_from_raw/3" do
    test "creates ToolCall with map arguments" do
      tool_call = StreamParser.tool_call_from_raw("call_123", "read_file", %{path: "/tmp/test.txt"})

      assert %ToolCall{} = tool_call
      assert ToolCall.name(tool_call) == "read_file"
      assert ToolCall.args_map(tool_call) == %{"path" => "/tmp/test.txt"}
    end

    test "creates ToolCall with string arguments" do
      args_json = ~s({"path":"/tmp/test.txt"})
      tool_call = StreamParser.tool_call_from_raw("call_123", "read_file", args_json)

      assert %ToolCall{} = tool_call
      assert ToolCall.args_json(tool_call) == args_json
    end

    test "generates ID when nil is passed" do
      tool_call = StreamParser.tool_call_from_raw(nil, "test_func", %{})

      assert tool_call.id =~ ~r/^call_/
    end
  end

  describe "tool_call wire format encoding" do
    test "ToolCall encodes to OpenAI-compatible wire format" do
      tool_call = StreamParser.tool_call_from_raw(
        "call_abc123",
        "read_file",
        %{path: "/tmp/data.json"}
      )

      # Encode to JSON and back to verify wire format
      json = Jason.encode!(tool_call) |> Jason.decode!()

      assert json == %{
        "id" => "call_abc123",
        "type" => "function",
        "function" => %{
          "name" => "read_file",
          "arguments" => ~s({"path":"/tmp/data.json"})
        }
      }
    end

    test "arguments remain as JSON string, not double-encoded" do
      args = ~s({"complex":{"nested":"value"}})
      tool_call = StreamParser.tool_call_from_raw("id", "func", args)

      json = Jason.encode!(tool_call) |> Jason.decode!()

      # Arguments should be the exact string, not escaped again
      assert json["function"]["arguments"] == args
    end
  end

  describe "extract_tool_calls/1" do
    test "extracts tool calls from stream chunks" do
      chunks = [
        %{type: :tool_call, name: "read_file", arguments: %{path: "/tmp"}, metadata: %{id: "call_1", index: 0}},
        %{type: :content, text: "Some text", metadata: %{}}
      ]

      tool_calls = StreamParser.extract_tool_calls(chunks)

      assert length(tool_calls) == 1
      assert [tool_call] = tool_calls
      assert ToolCall.name(tool_call) == "read_file"
      assert ToolCall.args_map(tool_call) == %{"path" => "/tmp"}
    end

    test "handles multiple tool calls" do
      chunks = [
        %{type: :tool_call, name: "read_file", arguments: %{path: "/a"}, metadata: %{id: "call_1", index: 0}},
        %{type: :tool_call, name: "write_file", arguments: %{path: "/b", content: "x"}, metadata: %{id: "call_2", index: 1}}
      ]

      tool_calls = StreamParser.extract_tool_calls(chunks)

      assert length(tool_calls) == 2
      assert Enum.map(tool_calls, &ToolCall.name/1) == ["read_file", "write_file"]
    end

    test "handles streamed argument fragments" do
      chunks = [
        %{type: :tool_call, name: "read_file", arguments: nil, metadata: %{id: "call_1", index: 0}},
        %{type: :meta, metadata: %{tool_call_args: %{index: 0, fragment: ~s({"path")}}},
        %{type: :meta, metadata: %{tool_call_args: %{index: 0, fragment: ~s(:"/tmp"})}}}
      ]

      tool_calls = StreamParser.extract_tool_calls(chunks)

      assert [tool_call] = tool_calls
      assert ToolCall.args_map(tool_call) == %{"path" => "/tmp"}
    end

    test "returns empty list when no tool calls in chunks" do
      chunks = [
        %{type: :content, text: "Hello", metadata: %{}},
        %{type: :meta, metadata: %{response_id: "resp_123"}}
      ]

      assert StreamParser.extract_tool_calls(chunks) == []
    end

    test "generates IDs for tool calls without explicit IDs" do
      chunks = [
        %{type: :tool_call, name: "func", arguments: %{}, metadata: %{}}
      ]

      [tool_call] = StreamParser.extract_tool_calls(chunks)

      assert tool_call.id =~ ~r/^call_/
    end
  end
end
