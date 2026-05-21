defmodule FrontmanServer.Tasks.MessageOptimizer.ConstrainImageDimensionsTest do
  use ExUnit.Case, async: true

  import FrontmanServer.ProvidersFixtures, only: [png_fixture: 2]

  alias FrontmanServer.Tasks.MessageOptimizer.ConstrainImageDimensions
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  describe "run/2" do
    test "replaces oversized user images for constrained providers" do
      messages = [
        %Message.User{
          content: [
            ContentPart.text("look"),
            ContentPart.image(png_fixture(9000, 1080), "image/png")
          ]
        }
      ]

      [result] = ConstrainImageDimensions.run(messages, provider: "anthropic")

      assert Enum.map(result.content, & &1.type) == [:text, :text]
      assert Enum.at(result.content, 1).text =~ "Image removed"
      assert Enum.at(result.content, 1).text =~ "9000x1080px"
      assert Enum.at(result.content, 1).text =~ "7680px provider limit"
    end

    test "replaces oversized tool images for constrained providers" do
      messages = [
        %Message.Tool{
          name: "take_screenshot",
          tool_call_id: "tc1",
          content: [ContentPart.image(png_fixture(1920, 9000), "image/png")]
        }
      ]

      [result] = ConstrainImageDimensions.run(messages, provider: "anthropic")

      [part] = result.content
      assert part.type == :text
      assert part.text =~ "Image removed"
      assert part.text =~ "1920x9000px"
    end

    test "preserves images for providers without a hard max" do
      messages = [
        %Message.User{content: [ContentPart.image(png_fixture(9000, 1080), "image/png")]}
      ]

      assert ConstrainImageDimensions.run(messages, provider: "openrouter") == messages
    end

    test "preserves images when provider is absent" do
      messages = [
        %Message.User{content: [ContentPart.image(png_fixture(9000, 1080), "image/png")]}
      ]

      assert ConstrainImageDimensions.run(messages) == messages
    end
  end
end
