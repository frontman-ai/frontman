defmodule FrontmanServer.Tasks.MessageOptimizer.StripUnsupportedImagesTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.MessageOptimizer.StripUnsupportedImages
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  describe "run/2" do
    test "strips images for text-only models" do
      messages = [
        %Message.User{
          content: [
            ContentPart.text("look"),
            ContentPart.image("image-bytes", "image/png"),
            ContentPart.image_url("https://example.com/image.png")
          ]
        }
      ]

      [result] =
        StripUnsupportedImages.run(messages, model: "nvidia:deepseek-ai/deepseek-v4-flash")

      assert Enum.map(result.content, & &1.type) == [:text, :text, :text]
      assert Enum.at(result.content, 1).text =~ "Image omitted"
      assert Enum.at(result.content, 2).text =~ "Image omitted"
    end

    test "preserves images for multimodal models" do
      messages = [
        %Message.User{
          content: [ContentPart.text("look"), ContentPart.image("image-bytes", "image/png")]
        }
      ]

      assert StripUnsupportedImages.run(messages, model: "nvidia:moonshotai/kimi-k2.6") ==
               messages
    end

    test "preserves images when no model is provided" do
      messages = [%Message.User{content: [ContentPart.image("image-bytes", "image/png")]}]

      assert StripUnsupportedImages.run(messages) == messages
    end
  end
end
