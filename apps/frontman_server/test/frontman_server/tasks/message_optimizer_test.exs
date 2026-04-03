defmodule FrontmanServer.Tasks.MessageOptimizerTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.MessageOptimizer
  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  @page_context """

  [Current Page Context]
  URL: https://example.com
  Viewport: 1920x1080
  Title: Test\
  """

  describe "find_old_boundary/1" do
    test "returns index after last assistant message" do
      messages = [
        %Message{role: :user, content: []},
        %Message{role: :assistant, content: []},
        %Message{role: :user, content: []}
      ]

      assert MessageOptimizer.find_old_boundary(messages) == 2
    end

    test "returns 0 when no assistant messages" do
      messages = [%Message{role: :user, content: []}]
      assert MessageOptimizer.find_old_boundary(messages) == 0
    end

    test "handles multiple assistant messages" do
      messages = [
        %Message{role: :user, content: []},
        %Message{role: :assistant, content: []},
        %Message{role: :tool, content: [], tool_call_id: "tc1"},
        %Message{role: :assistant, content: []},
        %Message{role: :user, content: []}
      ]

      assert MessageOptimizer.find_old_boundary(messages) == 4
    end
  end

  describe "optimize/2" do
    test "full pipeline: decays old images, strips tool metadata, dedupes context" do
      tool_json =
        Jason.encode!(%{
          "content" => "file data",
          "start_line" => 1,
          "lines_returned" => 50,
          "total_lines" => 200
        })

      messages = [
        # Turn 1: user with screenshot + page context
        %Message{
          role: :user,
          content: [
            ContentPart.text("click the button" <> @page_context),
            ContentPart.image("screenshot_data", "image/png")
          ]
        },
        # Assistant response
        %Message{role: :assistant, content: [ContentPart.text("I clicked it")]},
        # Tool result with pagination metadata
        %Message{role: :tool, content: [ContentPart.text(tool_json)], tool_call_id: "tc1"},
        # Second assistant response
        %Message{role: :assistant, content: [ContentPart.text("read the file")]},
        # Turn 2: user with same page context + new screenshot
        %Message{
          role: :user,
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

      # Old tool result (index 2) has metadata stripped
      tool_text = Enum.at(result, 2).content |> hd() |> Map.get(:text)
      decoded = Jason.decode!(tool_text)
      assert decoded == %{"content" => "file data"}

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
        %Message{
          role: :user,
          content: [ContentPart.image("big_data", "image/png")]
        },
        %Message{role: :assistant, content: [ContentPart.text("ok")]}
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
            %Message{
              role: :assistant,
              content: [],
              tool_calls: [ReqLLM.ToolCall.new(id, "mcp_read_file", "{}")]
            },
            %Message{
              role: :tool,
              tool_call_id: id,
              content: [ContentPart.text(large_payload)]
            }
          ]
        end)

      # Final (live) assistant turn, not yet replied — still needs full tool result
      messages =
        [%Message{role: :user, content: [ContentPart.text("do work")]}] ++
          tool_pairs

      optimized = MessageOptimizer.optimize(messages)

      tool_results =
        Enum.filter(optimized, &(&1.role == :tool))

      # Every tool result should be truncated to <= default 50KB + suffix overhead
      Enum.each(tool_results, fn msg ->
        text = hd(msg.content).text
        # After truncation: starts with 51_200 bytes of content + suffix
        assert byte_size(text) < 100_000,
               "Expected tool result to be truncated, got #{byte_size(text)} bytes"

        assert text =~ "[Output truncated:"
      end)
    end
  end
end
