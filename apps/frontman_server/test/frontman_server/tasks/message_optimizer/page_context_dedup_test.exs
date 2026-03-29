defmodule FrontmanServer.Tasks.MessageOptimizer.PageContextDedupTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.MessageOptimizer.PageContextDedup
  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  @page_context """

  [Current Page Context]
  URL: https://example.com
  Viewport: 1920x1080
  DPR: 2
  Title: Example
  Color scheme: light
  Scroll Y: 0\
  """

  @different_context """

  [Current Page Context]
  URL: https://other.com
  Viewport: 1920x1080
  DPR: 2
  Title: Other
  Color scheme: dark
  Scroll Y: 100\
  """

  describe "run/2" do
    test "strips duplicate page context from consecutive user messages" do
      messages = [
        %Message{role: :user, content: [ContentPart.text("click the button" <> @page_context)]},
        %Message{role: :assistant, content: [ContentPart.text("done")]},
        %Message{role: :user, content: [ContentPart.text("now scroll down" <> @page_context)]}
      ]

      result = PageContextDedup.run(messages)

      # First user message: context kept
      first_text = Enum.at(result, 0).content |> hd() |> Map.get(:text)
      assert first_text =~ "[Current Page Context]"
      assert first_text =~ "https://example.com"

      # Second user message: duplicate context stripped
      second_text = Enum.at(result, 2).content |> hd() |> Map.get(:text)
      refute second_text =~ "[Current Page Context]"
      assert second_text == "now scroll down"
    end

    test "keeps context when it changes between user messages" do
      messages = [
        %Message{role: :user, content: [ContentPart.text("page one" <> @page_context)]},
        %Message{role: :assistant, content: [ContentPart.text("ok")]},
        %Message{role: :user, content: [ContentPart.text("page two" <> @different_context)]}
      ]

      result = PageContextDedup.run(messages)

      second_text = Enum.at(result, 2).content |> hd() |> Map.get(:text)
      assert second_text =~ "[Current Page Context]"
      assert second_text =~ "https://other.com"
    end

    test "preserves messages without page context" do
      messages = [
        %Message{role: :user, content: [ContentPart.text("hello")]},
        %Message{role: :assistant, content: [ContentPart.text("hi")]}
      ]

      result = PageContextDedup.run(messages)
      assert result == messages
    end

    test "drops empty text parts when stripping context-only content" do
      messages = [
        %Message{role: :user, content: [ContentPart.text(@page_context)]},
        %Message{role: :assistant, content: [ContentPart.text("ok")]},
        %Message{role: :user, content: [ContentPart.text(@page_context)]}
      ]

      result = PageContextDedup.run(messages)

      # Second user message: context stripped, empty text part dropped
      second_content = Enum.at(result, 2).content
      refute Enum.any?(second_content, &(&1.type == :text and &1.text == ""))
    end

    test "never produces a message with empty content list" do
      messages = [
        %Message{role: :user, content: [ContentPart.text(@page_context)]},
        %Message{role: :assistant, content: [ContentPart.text("ok")]},
        %Message{role: :user, content: [ContentPart.text(@page_context)]}
      ]

      result = PageContextDedup.run(messages)

      # Second user message had only page context — after dedup, content must not be empty
      second_msg = Enum.at(result, 2)
      assert second_msg.content != []
    end

    test "handles empty message list" do
      assert PageContextDedup.run([]) == []
    end
  end
end
