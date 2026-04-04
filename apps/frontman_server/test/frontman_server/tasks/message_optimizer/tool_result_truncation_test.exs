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

    test "truncation at a multi-byte UTF-8 character boundary produces valid UTF-8" do
      # binary_part/3 is byte-level. If max_bytes falls inside a multi-byte character
      # (e.g., an emoji = 4 bytes), the truncated binary is invalid UTF-8.
      # Jason.encode! will raise on invalid UTF-8, crashing the LLM request.
      #
      # Construct a string where a 4-byte emoji (🐞 = 0xF0 0x9F 0x90 0x9E) straddles
      # the truncation boundary. With max_bytes=100: 98 ASCII bytes + the first byte
      # of the emoji lands at byte 99, which is inside the 100-byte limit but splits
      # the character.
      boundary_text = String.duplicate("a", 98) <> "🐞" <> String.duplicate("b", 100)

      messages = [
        %Message{
          role: :tool,
          tool_call_id: "tc_utf8",
          content: [ContentPart.text(boundary_text)]
        }
      ]

      [result] = ToolResultTruncation.run(messages, tool_result_max_bytes: @max_bytes)
      [part] = result.content

      # Must be valid UTF-8 — Jason.encode! would raise otherwise.
      assert String.valid?(part.text),
             "Truncated text is not valid UTF-8: #{inspect(part.text, binaries: :as_binaries)}"

      # Must still contain the truncation suffix.
      assert part.text =~ "[Output truncated:"
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
