defmodule FrontmanServer.Tasks.MessageOptimizer.ToolResultCompactionTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.MessageOptimizer.ToolResultCompaction
  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  describe "run/3" do
    test "replaces old non-image tool results with recoverable placeholders" do
      messages = [
        %Message{role: :tool, content: [ContentPart.text("full contents")], tool_call_id: "tc1"},
        %Message{role: :assistant, content: [ContentPart.text("got it")]},
        %Message{role: :tool, content: [ContentPart.text("live contents")], tool_call_id: "tc2"}
      ]

      result = ToolResultCompaction.run(messages, 2)

      old_text = Enum.at(result, 0).content |> hd() |> Map.get(:text)
      assert old_text == "[Omitted data. For the data, use get_interaction for tc1.]"

      live_text = Enum.at(result, 2).content |> hd() |> Map.get(:text)
      assert live_text == "live contents"
    end

    test "leaves old tool results without IDs alone" do
      messages = [
        %Message{
          role: :tool,
          content: [ContentPart.text("plain text result")]
        },
        %Message{role: :assistant, content: [ContentPart.text("ok")]}
      ]

      result = ToolResultCompaction.run(messages, 2)
      assert Enum.at(result, 0).content |> hd() |> Map.get(:text) == "plain text result"
    end

    test "replaces old non-image tool results and preserves image tool results" do
      messages = [
        %Message{
          role: :tool,
          name: "read_file",
          content: [ContentPart.text("full contents")],
          tool_call_id: "tc1"
        },
        %Message{
          role: :tool,
          name: "take_screenshot",
          content: [ContentPart.image("image-bytes", "image/png")],
          tool_call_id: "tc2"
        },
        %Message{role: :assistant, content: [ContentPart.text("I saw it")]}
      ]

      [omitted, image | _] = ToolResultCompaction.run(messages, 3)

      assert hd(omitted.content).text ==
               "[Omitted data. For the data, use get_interaction for tc1.]"

      assert image.content == [ContentPart.image("image-bytes", "image/png")]
    end

    test "skips non-tool messages even if old" do
      messages = [
        %Message{role: :user, content: [ContentPart.text("plain text")]},
        %Message{role: :assistant, content: [ContentPart.text("ok")]}
      ]

      result = ToolResultCompaction.run(messages, 2)
      assert result == messages
    end
  end
end
