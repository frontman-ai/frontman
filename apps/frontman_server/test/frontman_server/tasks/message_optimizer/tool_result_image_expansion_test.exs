defmodule FrontmanServer.Tasks.MessageOptimizer.ToolResultImageExpansionTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.MessageOptimizer.ToolResultImageExpansion
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  describe "run/2" do
    test "converts take_screenshot JSON text into image content" do
      data_url = "data:image/png;base64,#{Base.encode64("image-bytes")}"

      messages = [
        %Message.Tool{
          name: "mcp_take_screenshot",
          tool_call_id: "tc1",
          content: [ContentPart.text(Jason.encode!(%{"screenshot" => data_url}))]
        }
      ]

      [result] = ToolResultImageExpansion.run(messages)

      assert result.content == [ContentPart.image("image-bytes", "image/png")]
    end

    test "converts web_fetch image JSON text into image content" do
      data_url = "data:image/jpeg;base64,#{Base.encode64("image-bytes")}"

      messages = [
        %Message.Tool{
          name: "web_fetch",
          tool_call_id: "tc1",
          content: [ContentPart.text(Jason.encode!(%{"image" => data_url}))]
        }
      ]

      [result] = ToolResultImageExpansion.run(messages)

      assert result.content == [ContentPart.image("image-bytes", "image/jpeg")]
    end

    test "converts get_tool_result screenshot JSON text into image content" do
      data_url = "data:image/png;base64,#{Base.encode64("image-bytes")}"

      messages = [
        %Message.Tool{
          name: "get_tool_result",
          tool_call_id: "tc-get-result",
          content: [ContentPart.text(Jason.encode!(%{"screenshot" => data_url}))]
        }
      ]

      [result] = ToolResultImageExpansion.run(messages)

      assert result.content == [ContentPart.image("image-bytes", "image/png")]
    end

    test "converts get_tool_result web_fetch image JSON text into image content" do
      data_url = "data:image/jpeg;base64,#{Base.encode64("image-bytes")}"

      messages = [
        %Message.Tool{
          name: "get_tool_result",
          tool_call_id: "tc-get-result",
          content: [ContentPart.text(Jason.encode!(%{"type" => "image", "image" => data_url}))]
        }
      ]

      [result] = ToolResultImageExpansion.run(messages)

      assert result.content == [ContentPart.image("image-bytes", "image/jpeg")]
    end

    test "leaves non-image tool results unchanged" do
      messages = [
        %Message.Tool{
          name: "read_file",
          tool_call_id: "tc1",
          content: [ContentPart.text("file contents")]
        }
      ]

      assert ToolResultImageExpansion.run(messages) == messages
    end
  end
end
