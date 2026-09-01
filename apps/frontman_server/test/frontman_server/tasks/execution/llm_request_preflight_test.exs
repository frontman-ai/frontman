defmodule FrontmanServer.Tasks.Execution.LLMRequestPreflightTest do
  use ExUnit.Case, async: false

  import FrontmanServer.ProvidersFixtures, only: [png_fixture: 2]

  alias FrontmanServer.CurrentPageContext
  alias FrontmanServer.Tasks.Execution.LLMRequestPreflight
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  @page_context CurrentPageContext.to_prompt_section(%{
                  url: "https://example.com",
                  viewport_width: 1920,
                  viewport_height: 1080,
                  title: "Test"
                })

  @different_page_context CurrentPageContext.to_prompt_section(%{
                            url: "https://other.example.com",
                            viewport_width: 1280,
                            viewport_height: 720,
                            title: "Other"
                          })

  @tool_result_max_bytes 100

  describe "run/2" do
    test "handles empty message list" do
      assert LLMRequestPreflight.run([]) == []
    end

    test "backfills a placeholder result for an unresolved tool call" do
      messages = [
        %Message.Assistant{
          tool_calls: [
            %SwarmAi.ToolCall{id: "tc-a", name: "grep", arguments: "{}"},
            %SwarmAi.ToolCall{id: "tc-b", name: "grep", arguments: "{}"}
          ]
        },
        %Message.Tool{name: "grep", tool_call_id: "tc-b", content: [ContentPart.text("hit")]}
      ]

      assert [
               %Message.Assistant{},
               %Message.Tool{tool_call_id: "tc-a", content: [%ContentPart{text: text}]},
               %Message.Tool{tool_call_id: "tc-b", content: [%ContentPart{text: "hit"}]}
             ] = LLMRequestPreflight.run(messages)

      assert text =~ "interrupted"
    end

    test "leaves live non-image tool results unchanged" do
      messages = [
        %Message.Tool{
          name: "read_file",
          tool_call_id: "tc-read",
          content: [ContentPart.text("file contents")]
        }
      ]

      assert LLMRequestPreflight.run(messages) == messages
    end

    @tag :capture_log
    test "removes oversized images for constrained providers" do
      Sentry.Test.setup_sentry(dedup_events: false)

      messages = [
        %Message.User{
          content: [
            ContentPart.text("look"),
            ContentPart.image(png_fixture(9000, 1080), "image/png")
          ]
        }
      ]

      model = %LLMDB.Model{
        provider: :anthropic,
        id: "claude-sonnet-4-6"
      }

      [result] = LLMRequestPreflight.run(messages, model: model)

      [_text, image_placeholder] = result.content
      assert image_placeholder.type == :text
      assert image_placeholder.text =~ "Image removed"
      assert image_placeholder.text =~ "9000x1080px"
      assert image_placeholder.text =~ "7680px provider limit"

      assert [] = Sentry.Test.pop_sentry_reports()
    end

    @tag :capture_log
    test "limits OpenRouter Anthropic requests with more than 20 images" do
      model = %LLMDB.Model{provider: :openrouter, id: "anthropic/claude-sonnet-5"}
      [result] = LLMRequestPreflight.run(many_image_messages(3000), model: model)

      [_text, image_placeholder | _urls] = result.content
      assert image_placeholder.text =~ "2000px provider limit"
    end

    test "keeps changed page context" do
      messages = [
        %Message.User{content: [ContentPart.text("page one" <> @page_context)]},
        %Message.Assistant{content: [ContentPart.text("ok")]},
        %Message.User{content: [ContentPart.text("page two" <> @different_page_context)]}
      ]

      result = LLMRequestPreflight.run(messages)

      second_text = Enum.at(result, 2).content |> hd() |> Map.fetch!(:text)
      assert second_text =~ "[Current Page Context]"
      assert second_text =~ "https://other.example.com"
    end

    test "replaces duplicate context-only user messages with a placeholder" do
      messages = [
        %Message.User{content: [ContentPart.text(@page_context)]},
        %Message.Assistant{content: [ContentPart.text("ok")]},
        %Message.User{content: [ContentPart.text(@page_context)]}
      ]

      result = LLMRequestPreflight.run(messages)

      second_content = Enum.at(result, 2).content
      refute second_content == []
      assert second_content == [ContentPart.text(CurrentPageContext.unchanged_placeholder())]
    end

    test "dedupes page context without stripping following sections" do
      annotations_section = """

      [Annotated Elements]
      Annotation 1:
        Tag: <button>
      """

      messages = [
        %Message.User{content: [ContentPart.text("first" <> @page_context)]},
        %Message.Assistant{content: [ContentPart.text("ok")]},
        %Message.User{
          content: [ContentPart.text("second" <> @page_context <> annotations_section)]
        }
      ]

      result = LLMRequestPreflight.run(messages)

      second_text = Enum.at(result, 2).content |> hd() |> Map.fetch!(:text)
      refute second_text =~ CurrentPageContext.header()
      assert second_text =~ "second"
      assert second_text =~ "[Annotated Elements]"
      assert second_text =~ "Annotation 1"
    end

    test "truncates live text tool results at valid UTF-8 boundaries" do
      boundary_text = String.duplicate("a", 98) <> "🐞" <> String.duplicate("b", 100)

      messages = [
        %Message.Tool{
          name: "read_file",
          tool_call_id: "tc-utf8",
          content: [ContentPart.text(boundary_text)]
        }
      ]

      [result] =
        LLMRequestPreflight.run(messages, tool_result_max_bytes: @tool_result_max_bytes)

      text = hd(result.content).text
      assert String.valid?(text)
      assert text =~ "[Output truncated:"
      assert text =~ "#{byte_size(boundary_text)} bytes total"
      assert text =~ "showing first #{@tool_result_max_bytes}"
      assert text =~ "get_tool_result with tool_call_id tc-utf8"
    end

    test "truncates live get_tool_result with its tool call ID" do
      source_tool_call_id = "tc-original"
      get_tool_call_id = "tc-get"
      large_text = String.duplicate("r", 200)

      messages = [
        %Message.Assistant{
          content: [],
          tool_calls: [
            %SwarmAi.ToolCall{
              id: get_tool_call_id,
              name: "get_tool_result",
              arguments: Jason.encode!(%{"tool_call_id" => source_tool_call_id})
            }
          ]
        },
        %Message.Tool{
          name: "get_tool_result",
          tool_call_id: get_tool_call_id,
          content: [ContentPart.text(large_text)]
        }
      ]

      [_assistant, result] =
        LLMRequestPreflight.run(messages, tool_result_max_bytes: @tool_result_max_bytes)

      text = hd(result.content).text
      assert text =~ "[Output truncated:"
      assert text =~ "get_tool_result with tool_call_id #{get_tool_call_id}"
      refute text =~ "get_tool_result with tool_call_id #{source_tool_call_id}"
    end

    test "leaves under-limit tool text unchanged" do
      short_text = String.duplicate("a", 50)

      messages = [
        %Message.Tool{
          name: "read_file",
          tool_call_id: "tc-short",
          content: [ContentPart.text(short_text)]
        }
      ]

      [result] =
        LLMRequestPreflight.run(messages, tool_result_max_bytes: @tool_result_max_bytes)

      assert hd(result.content).text == short_text
    end

    test "does not truncate non-tool messages" do
      large_text = String.duplicate("a", 200)

      messages = [
        %Message.User{content: [ContentPart.text(large_text)]},
        %Message.Assistant{content: [ContentPart.text(large_text)]}
      ]

      result =
        LLMRequestPreflight.run(messages, tool_result_max_bytes: @tool_result_max_bytes)

      Enum.each(result, fn msg ->
        assert hd(msg.content).text == large_text
      end)
    end

    test "truncates only oversized text parts in multi-part tool results" do
      large_text = String.duplicate("b", 200)
      small_text = String.duplicate("s", 10)

      messages = [
        %Message.Tool{
          name: "read_file",
          tool_call_id: "tc-multi",
          content: [ContentPart.text(large_text), ContentPart.text(small_text)]
        }
      ]

      [result] =
        LLMRequestPreflight.run(messages, tool_result_max_bytes: @tool_result_max_bytes)

      [first, second] = result.content
      assert first.text =~ "[Output truncated:"
      assert first.text =~ "200 bytes total"
      assert second.text == small_text
    end

    test "truncates large tool results accumulated across many loop steps" do
      large_payload = String.duplicate("x", 100_000)

      tool_pairs =
        Enum.flat_map(1..10, fn i ->
          id = "tc#{i}"

          [
            %Message.Assistant{
              content: [],
              tool_calls: [%SwarmAi.ToolCall{id: id, name: "mcp_read_file", arguments: "{}"}]
            },
            %Message.Tool{
              name: "read_file",
              tool_call_id: id,
              content: [ContentPart.text(large_payload)]
            }
          ]
        end)

      messages =
        [%Message.User{content: [ContentPart.text("do work")]}] ++
          tool_pairs

      preflighted = LLMRequestPreflight.run(messages)

      tool_results =
        Enum.filter(preflighted, &match?(%Message.Tool{}, &1))

      Enum.each(tool_results, fn msg ->
        text = hd(msg.content).text

        assert byte_size(text) < 100_000,
               "Expected tool result to be truncated, got #{byte_size(text)} bytes"

        assert text =~ "[Output truncated:"
        assert text =~ "get_tool_result"
      end)
    end

    test "strips unsupported images before provider dimension checks" do
      messages = [
        %Message.User{
          content: [
            ContentPart.text("look"),
            ContentPart.image(png_fixture(9000, 1080), "image/png")
          ]
        }
      ]

      model = %LLMDB.Model{
        provider: :nvidia,
        id: "deepseek-ai/deepseek-v4-flash",
        modalities: %{input: [:text], output: [:text]}
      }

      [result] = LLMRequestPreflight.run(messages, model: model)

      [_text, image_placeholder] = result.content
      assert image_placeholder.type == :text
      assert image_placeholder.text =~ "Image omitted"
      refute image_placeholder.text =~ "Image removed"
    end
  end

  defp image_messages(width) do
    [
      %Message.User{
        content: [
          ContentPart.text("look"),
          ContentPart.image(png_fixture(width, 1080), "image/png")
        ]
      }
    ]
  end

  defp many_image_messages(width) do
    [message] = image_messages(width)
    urls = Enum.map(1..20, fn i -> ContentPart.image_url("https://example.com/#{i}.png") end)
    [%{message | content: message.content ++ urls}]
  end
end
