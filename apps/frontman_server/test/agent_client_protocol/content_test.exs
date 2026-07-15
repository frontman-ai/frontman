defmodule AgentClientProtocol.ContentTest do
  use ExUnit.Case, async: true

  alias AgentClientProtocol.Content
  alias AgentClientProtocol.Content.{ContentItem, TextBlock}
  alias FrontmanServer.Tasks.Interaction

  describe "text/1" do
    test "builds TextBlock struct" do
      assert %TextBlock{text: "Hello"} = Content.text("Hello")
    end
  end

  describe "wrap/1" do
    test "wraps TextBlock in ContentItem" do
      block = Content.text("Hello")
      assert %ContentItem{content: %TextBlock{}} = Content.wrap(block)
    end
  end

  describe "from_tool_result/1" do
    test "formats binary as text" do
      assert [%ContentItem{content: %TextBlock{text: "Hello"}}] =
               Content.from_tool_result("Hello")
    end

    test "formats other types using inspect" do
      assert [%ContentItem{content: %TextBlock{text: "{:ok, 123}"}}] =
               Content.from_tool_result({:ok, 123})
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

      assert [text, annotation, screenshot, image, page] = Content.from_user_message(message)
      assert text == %{"type" => "text", "text" => "Hello"}
      assert annotation["resource"]["_meta"]["custom"] == "value"
      assert annotation["resource"]["_meta"]["bounding_box"]["width"] == 3.0
      assert screenshot["resource"]["_meta"]["annotation_screenshot"]
      assert image["resource"]["resource"]["mimeType"] == "image/jpeg"
      assert page["resource"]["resource"]["uri"] == "page://https://example.com"
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

      assert annotation["resource"]["resource"] == %{
               "uri" => "elementor://post/42/element/b535bb8",
               "mimeType" => "text/plain",
               "text" => "Annotated Elementor element: <div> widget html (Inspect before editing)"
             }

      assert annotation["resource"]["_meta"]["selector"] ==
               ".elementor-element-b535bb8"
    end
  end

  describe "Jason.Encoder" do
    test "encodes TextBlock to ACP format" do
      block = Content.text("Hello")
      assert Jason.decode!(Jason.encode!(block)) == %{"type" => "text", "text" => "Hello"}
    end

    test "encodes ContentItem to ACP format" do
      item = Content.text("Hello") |> Content.wrap()
      decoded = Jason.decode!(Jason.encode!(item))

      assert decoded == %{
               "type" => "content",
               "content" => %{"type" => "text", "text" => "Hello"}
             }
    end

    test "encodes from_tool_result output" do
      [item] = Content.from_tool_result("Hello")
      decoded = Jason.decode!(Jason.encode!(item))

      assert decoded == %{
               "type" => "content",
               "content" => %{"type" => "text", "text" => "Hello"}
             }
    end
  end
end
