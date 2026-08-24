defmodule AgentClientProtocol.ContentTest do
  use ExUnit.Case, async: true

  alias AgentClientProtocol.Content
  alias FrontmanServer.ProtocolSchema
  alias FrontmanServer.Tasks.Interaction

  @timestamp ~U[2026-07-15 10:00:00.000000Z]

  describe "from_tool_result/1" do
    test "preserves typed multipart content in order" do
      text = %{"type" => "text", "text" => "Hello"}
      image = %{"type" => "image", "data" => "base64", "mimeType" => "image/png"}

      assert Content.from_tool_result(%{"content" => [text, image]}) == [
               %{"type" => "content", "content" => text},
               %{"type" => "content", "content" => image}
             ]
    end

    test "rejects malformed known content" do
      assert_raise FunctionClauseError, fn ->
        Content.from_tool_result(%{"content" => [%{"type" => "image", "data" => "base64"}]})
      end
    end
  end

  describe "from_user_message/1" do
    test "reconstructs text, annotation, screenshot, image, and page blocks" do
      message = %Interaction.UserMessage{
        messages: ["Hello"],
        annotations: [
          %Interaction.Annotation{
            annotation_id: "ann-1",
            tag_name: "button",
            metadata: %{"custom" => "value"},
            bounding_box: %Interaction.BoundingBox{x: 1.0, y: 2.0, width: 3.0, height: 4.0},
            screenshot: %Interaction.Screenshot{blob: "image", mime_type: "image/png"}
          }
        ],
        images: [
          %Interaction.UserImage{
            blob: "upload",
            mime_type: "image/jpeg",
            filename: "photo.jpg"
          }
        ],
        current_page: %Interaction.CurrentPage{url: "https://example.com"}
      }

      blocks = Content.from_user_message(message)
      assert [text, annotation, screenshot, image, page] = blocks
      assert text == %{"type" => "text", "text" => "Hello"}
      assert annotation["_meta"]["custom"] == "value"
      assert annotation["_meta"]["bounding_box"]["width"] == 3.0
      assert screenshot["_meta"]["annotation_screenshot"]
      assert image["resource"]["mimeType"] == "image/jpeg"
      assert page["resource"]["uri"] == "page://https://example.com"

      blocks
      |> Enum.with_index()
      |> Enum.each(fn {content, index} ->
        AgentClientProtocol.build_user_message_chunk_notification(
          "session-1",
          "resource-#{index}",
          content,
          "executor-id",
          @timestamp
        )
        |> ProtocolSchema.validate_upstream_acp!()
      end)
    end

    test "reconstructs Elementor annotation URI and text from persisted metadata" do
      message = %Interaction.UserMessage{
        annotations: [
          %Interaction.Annotation{
            annotation_id: "ann-elementor",
            tag_name: "div",
            selector: ".elementor-element-b535bb8",
            metadata: %{
              "elementor" => %{
                "post_id" => 42,
                "element_id" => "b535bb8",
                "element_type" => "widget",
                "widget_type" => "html",
                "edit_hint" => "Inspect before editing"
              }
            }
          }
        ]
      }

      assert [annotation] = Content.from_user_message(message)

      assert annotation["resource"] == %{
               "uri" => "elementor://post/42/element/b535bb8",
               "mimeType" => "text/plain",
               "text" => "Annotated Elementor element: <div> widget html (Inspect before editing)"
             }

      assert annotation["_meta"]["selector"] ==
               ".elementor-element-b535bb8"
    end
  end
end
