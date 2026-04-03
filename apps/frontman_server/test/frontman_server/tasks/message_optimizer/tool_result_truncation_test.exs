defmodule FrontmanServer.Tasks.MessageOptimizer.ToolResultTruncationTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.MessageOptimizer.ToolResultTruncation
  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  @max_bytes 100

  describe "run/2" do
    test "truncates text content exceeding max_bytes" do
      large_text = String.duplicate("a", 200)

      messages = [
        %Message{
          role: :tool,
          tool_call_id: "tc1",
          content: [ContentPart.text(large_text)]
        }
      ]

      [result] = ToolResultTruncation.run(messages, tool_result_max_bytes: @max_bytes)
      [part] = result.content

      assert byte_size(part.text) > @max_bytes
      assert String.starts_with?(part.text, String.duplicate("a", @max_bytes))
      assert part.text =~ "[Output truncated:"
    end

    test "leaves text content within max_bytes unchanged" do
      short_text = String.duplicate("a", 50)

      messages = [
        %Message{
          role: :tool,
          tool_call_id: "tc1",
          content: [ContentPart.text(short_text)]
        }
      ]

      [result] = ToolResultTruncation.run(messages, tool_result_max_bytes: @max_bytes)
      assert hd(result.content).text == short_text
    end

    test "only applies to :tool role messages" do
      large_text = String.duplicate("a", 200)

      messages = [
        %Message{role: :user, content: [ContentPart.text(large_text)]},
        %Message{role: :assistant, content: [ContentPart.text(large_text)]}
      ]

      result = ToolResultTruncation.run(messages, tool_result_max_bytes: @max_bytes)

      Enum.each(result, fn msg ->
        assert hd(msg.content).text == large_text
      end)
    end

    test "handles tool result with multiple content parts" do
      large_text = String.duplicate("b", 200)
      small_text = String.duplicate("s", 10)

      messages = [
        %Message{
          role: :tool,
          tool_call_id: "tc1",
          content: [ContentPart.text(large_text), ContentPart.text(small_text)]
        }
      ]

      [result] = ToolResultTruncation.run(messages, tool_result_max_bytes: @max_bytes)
      [first, second] = result.content

      assert first.text =~ "[Output truncated:"
      assert second.text == small_text
    end

    test "truncation suffix includes byte counts" do
      large_text = String.duplicate("x", 200)

      messages = [
        %Message{
          role: :tool,
          tool_call_id: "tc1",
          content: [ContentPart.text(large_text)]
        }
      ]

      [result] = ToolResultTruncation.run(messages, tool_result_max_bytes: @max_bytes)
      text = hd(result.content).text

      assert text =~ "200 bytes total"
      assert text =~ "showing first #{@max_bytes}"
    end
  end
end
