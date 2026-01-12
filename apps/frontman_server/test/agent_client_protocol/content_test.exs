defmodule AgentClientProtocol.ContentTest do
  use ExUnit.Case, async: true

  alias AgentClientProtocol.Content
  alias AgentClientProtocol.Content.{ContentItem, TextBlock}

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
    test "formats map as JSON-encoded text" do
      [%ContentItem{content: %TextBlock{text: text}}] =
        Content.from_tool_result(%{"key" => "value"})

      assert Jason.decode!(text) == %{"key" => "value"}
    end

    test "formats binary as text" do
      assert [%ContentItem{content: %TextBlock{text: "Hello"}}] =
               Content.from_tool_result("Hello")
    end

    test "formats other types using inspect" do
      assert [%ContentItem{content: %TextBlock{text: "{:ok, 123}"}}] =
               Content.from_tool_result({:ok, 123})
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
