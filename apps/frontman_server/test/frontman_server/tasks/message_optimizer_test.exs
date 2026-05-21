defmodule FrontmanServer.Tasks.MessageOptimizerTest do
  use ExUnit.Case, async: true

  import FrontmanServer.ProvidersFixtures, only: [png_fixture: 2]

  alias FrontmanServer.Tasks.MessageOptimizer
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  @page_context """

  [Current Page Context]
  URL: https://example.com
  Viewport: 1920x1080
  Title: Test\
  """

  describe "find_old_boundary/1" do
    test "returns index after last assistant message" do
      messages = [
        %Message.User{content: []},
        %Message.Assistant{content: []},
        %Message.User{content: []}
      ]

      assert MessageOptimizer.find_old_boundary(messages) == 2
    end

    test "returns 0 when no assistant messages" do
      messages = [%Message.User{content: []}]
      assert MessageOptimizer.find_old_boundary(messages) == 0
    end

    test "handles multiple assistant messages" do
      messages = [
        %Message.User{content: []},
        %Message.Assistant{content: []},
        %Message.Tool{name: "read_file", content: [], tool_call_id: "tc1"},
        %Message.Assistant{content: []},
        %Message.User{content: []}
      ]

      assert MessageOptimizer.find_old_boundary(messages) == 4
    end
  end

  describe "optimize/2" do
    test "full pipeline: decays old images, compacts old tool results, dedupes context" do
      tool_json =
        Jason.encode!(%{
          "content" => "file data",
          "start_line" => 1,
          "lines_returned" => 50,
          "total_lines" => 200
        })

      messages = [
        # Turn 1: user with screenshot + page context
        %Message.User{
          content: [
            ContentPart.text("click the button" <> @page_context),
            ContentPart.image("screenshot_data", "image/png")
          ]
        },
        # Assistant response
        %Message.Assistant{content: [ContentPart.text("I clicked it")]},
        # Tool result with pagination metadata
        %Message.Tool{
          name: "read_file",
          content: [ContentPart.text(tool_json)],
          tool_call_id: "tc1"
        },
        # Second assistant response
        %Message.Assistant{content: [ContentPart.text("read the file")]},
        # Turn 2: user with same page context + new screenshot
        %Message.User{
          content: [
            ContentPart.text("now scroll down" <> @page_context),
            ContentPart.image("new_screenshot", "image/png")
          ]
        }
      ]

      result = MessageOptimizer.optimize(messages)

      # Old screenshot (index 0) replaced with placeholder
      user1_content = Enum.at(result, 0).content
      assert Enum.any?(user1_content, &(&1.text == "[image: previously analyzed]"))
      refute Enum.any?(user1_content, &(&1.type == :image))

      # Old tool result (index 2) is replaced with a recovery pointer
      tool_text = Enum.at(result, 2).content |> hd() |> Map.get(:text)

      assert tool_text ==
               "[Omitted data. For the data, use get_tool_result with tool_call_id tc1.]"

      # Duplicate page context stripped from second user message
      user2_text =
        Enum.at(result, 4).content
        |> Enum.find(&(&1.type == :text))
        |> Map.get(:text)

      refute user2_text =~ "[Current Page Context]"

      # Live screenshot (index 4) preserved
      assert Enum.any?(Enum.at(result, 4).content, &(&1.type == :image))
    end

    test "pass-through when disabled" do
      Application.put_env(:frontman_server, MessageOptimizer, enabled: false)

      messages = [
        %Message.User{
          content: [ContentPart.image("big_data", "image/png")]
        },
        %Message.Assistant{content: [ContentPart.text("ok")]}
      ]

      result = MessageOptimizer.optimize(messages)
      assert result == messages
    after
      Application.delete_env(:frontman_server, MessageOptimizer)
    end

    test "handles empty message list" do
      assert MessageOptimizer.optimize([]) == []
    end

    # Regression test: long tool-calling chains accumulate many tool results
    # inside the swarm loop without going through MessageOptimizer. When the
    # LLMClient calls MessageOptimizer.optimize() before each API request, old
    # large tool results must be truncated to stay within Anthropic's body limit.
    test "truncates large tool results accumulated across many loop steps" do
      # Simulate 10 tool call/result pairs (loop steps), each result 100KB
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

      # Final (live) assistant turn, not yet replied — still needs full tool result
      messages =
        [%Message.User{content: [ContentPart.text("do work")]}] ++
          tool_pairs

      optimized = MessageOptimizer.optimize(messages)

      tool_results =
        Enum.filter(optimized, &match?(%Message.Tool{}, &1))

      # Old results are compacted; the live result is truncated.
      Enum.each(Enum.take(tool_results, 9), fn msg ->
        assert hd(msg.content).text =~ "get_tool_result"
      end)

      Enum.each(Enum.drop(tool_results, 9), fn msg ->
        text = hd(msg.content).text

        assert byte_size(text) < 100_000,
               "Expected tool result to be truncated, got #{byte_size(text)} bytes"

        assert text =~ "[Output truncated:"
        assert text =~ "get_tool_result"
      end)
    end

    test "strips recovered get_tool_result images for text-only models" do
      data_url = "data:image/png;base64,#{Base.encode64("image-bytes")}"

      messages = [
        %Message.User{content: [ContentPart.text("recover screenshot")]},
        %Message.Assistant{
          content: [ContentPart.text("")],
          tool_calls: [%SwarmAi.ToolCall{id: "tc-get", name: "get_tool_result", arguments: "{}"}]
        },
        %Message.Tool{
          name: "get_tool_result",
          tool_call_id: "tc-get",
          content: [ContentPart.text(Jason.encode!(%{"screenshot" => data_url}))]
        }
      ]

      optimized =
        MessageOptimizer.optimize(messages, model: "nvidia:deepseek-ai/deepseek-v4-flash")

      [part] = Enum.at(optimized, 2).content
      assert part.type == :text
      assert part.text =~ "Image omitted"
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

      [result] =
        MessageOptimizer.optimize(messages,
          model: "nvidia:deepseek-ai/deepseek-v4-flash",
          provider: "anthropic"
        )

      [_text, image_placeholder] = result.content
      assert image_placeholder.type == :text
      assert image_placeholder.text =~ "Image omitted"
      refute image_placeholder.text =~ "Image removed"
    end

    test "compacts recovered get_tool_result images after the assistant has read them" do
      data_url = "data:image/png;base64,#{Base.encode64("image-bytes")}"

      messages = [
        %Message.User{content: [ContentPart.text("recover screenshot")]},
        %Message.Assistant{
          content: [ContentPart.text("")],
          tool_calls: [%SwarmAi.ToolCall{id: "tc-get", name: "get_tool_result", arguments: "{}"}]
        },
        %Message.Tool{
          name: "get_tool_result",
          tool_call_id: "tc-get",
          content: [ContentPart.text(Jason.encode!(%{"screenshot" => data_url}))]
        },
        %Message.Assistant{content: [ContentPart.text("I saw it")]},
        %Message.User{content: [ContentPart.text("continue")]}
      ]

      optimized = MessageOptimizer.optimize(messages)

      [part] = Enum.at(optimized, 2).content

      assert part.type == :text

      assert part.text ==
               "[Omitted data. For the data, use get_tool_result with tool_call_id tc-get.]"
    end
  end
end
