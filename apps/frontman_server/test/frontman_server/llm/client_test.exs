defmodule FrontmanServer.LLM.ClientTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.LLM.Client

  describe "extract_text/1" do
    test "extracts text from chunks" do
      chunks = [
        %{text: "Hello ", type: :text},
        %{text: "world", type: :text},
        %{text: "!", type: :text}
      ]

      assert Client.extract_text(chunks) == "Hello world!"
    end

    test "handles nil text in chunks" do
      chunks = [
        %{text: "Hello", type: :text},
        %{text: nil, type: :meta},
        %{text: " world", type: :text}
      ]

      assert Client.extract_text(chunks) == "Hello world"
    end

    test "returns empty string for empty chunks" do
      assert Client.extract_text([]) == ""
    end
  end

  describe "extract_tool_calls/1" do
    test "extracts tool calls from chunks" do
      chunks = [
        %{
          type: :tool_call,
          name: "calculator",
          arguments: %{},
          metadata: %{id: "call_123", index: 0}
        }
      ]

      tool_calls = Client.extract_tool_calls(chunks)
      assert length(tool_calls) == 1
      assert hd(tool_calls).name == "calculator"
      assert hd(tool_calls).id == "call_123"
    end

    test "returns empty list when no tool calls" do
      chunks = [
        %{text: "Hello", type: :text}
      ]

      assert Client.extract_tool_calls(chunks) == []
    end

    test "merges fragmented arguments" do
      chunks = [
        %{
          type: :tool_call,
          name: "calculator",
          arguments: %{},
          metadata: %{id: "call_123", index: 0}
        },
        %{
          type: :meta,
          text: "",
          metadata: %{tool_call_args: %{index: 0, fragment: "{\"x\":"}}
        },
        %{
          type: :meta,
          text: "",
          metadata: %{tool_call_args: %{index: 0, fragment: "42}"}}
        }
      ]

      tool_calls = Client.extract_tool_calls(chunks)
      assert length(tool_calls) == 1
      assert hd(tool_calls).arguments == %{"x" => 42}
    end
  end
end
