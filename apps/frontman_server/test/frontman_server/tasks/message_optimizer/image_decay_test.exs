defmodule FrontmanServer.Tasks.MessageOptimizer.ImageDecayTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.MessageOptimizer.ImageDecay
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  describe "run/3" do
    test "replaces images in old messages with placeholder text" do
      messages = [
        %Message.User{
          content: [ContentPart.text("look at this"), ContentPart.image("png_data", "image/png")]
        },
        %Message.Assistant{content: [ContentPart.text("I see a button")]},
        %Message.User{
          content: [ContentPart.text("now click it"), ContentPart.image("png_data2", "image/png")]
        }
      ]

      # old_boundary = 2 (after the assistant message at index 1)
      result = ImageDecay.run(messages, 2)

      # Old user message (index 0): image replaced
      [text1, placeholder] = Enum.at(result, 0).content
      assert text1.type == :text
      assert text1.text == "look at this"
      assert placeholder.type == :text
      assert placeholder.text == "[image: previously analyzed]"

      # Assistant message (index 1): untouched (no images anyway)
      assert Enum.at(result, 1) == Enum.at(messages, 1)

      # Live user message (index 2): image preserved
      [_text, img] = Enum.at(result, 2).content
      assert img.type == :image
      assert img.data == "png_data2"
    end

    test "replaces image_url parts in old messages" do
      messages = [
        %Message.User{content: [ContentPart.image_url("https://example.com/img.png")]},
        %Message.Assistant{content: [ContentPart.text("ok")]}
      ]

      result = ImageDecay.run(messages, 2)

      [placeholder] = Enum.at(result, 0).content
      assert placeholder.type == :text
      assert placeholder.text == "[image: previously analyzed]"
    end

    test "skips old tool messages" do
      messages = [
        %Message.Tool{
          name: "take_screenshot",
          tool_call_id: "tc1",
          content: [ContentPart.image("image-bytes", "image/png")]
        },
        %Message.Assistant{content: [ContentPart.text("ok")]}
      ]

      result = ImageDecay.run(messages, 2)

      assert Enum.at(result, 0) == Enum.at(messages, 0)
    end

    test "leaves text-only messages unchanged" do
      messages = [
        %Message.User{content: [ContentPart.text("hello")]},
        %Message.Assistant{content: [ContentPart.text("hi")]}
      ]

      result = ImageDecay.run(messages, 2)
      assert result == messages
    end

    test "no-ops when old_boundary is 0 (all live)" do
      messages = [
        %Message.User{content: [ContentPart.image("data", "image/png")]}
      ]

      result = ImageDecay.run(messages, 0)
      assert result == messages
    end

    test "handles messages with nil content" do
      messages = [
        %Message.Assistant{
          content: nil,
          tool_calls: [%SwarmAi.ToolCall{id: "1", name: "test", arguments: "{}"}]
        }
      ]

      result = ImageDecay.run(messages, 1)
      assert result == messages
    end
  end
end
