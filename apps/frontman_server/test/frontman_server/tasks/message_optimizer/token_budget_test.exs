defmodule FrontmanServer.Tasks.MessageOptimizer.TokenBudgetTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.MessageOptimizer.TokenBudget
  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  describe "estimate_tokens/1" do
    test "estimates text tokens as chars / 4" do
      messages = [
        %Message{role: :user, content: [ContentPart.text(String.duplicate("a", 400))]}
      ]

      assert TokenBudget.estimate_tokens(messages) == 100
    end

    test "counts flat cost per image" do
      messages = [
        %Message{role: :user, content: [ContentPart.image("data", "image/png")]}
      ]

      assert TokenBudget.estimate_tokens(messages) == 4000
    end

    test "sums text and images" do
      messages = [
        %Message{
          role: :user,
          content: [
            ContentPart.text(String.duplicate("a", 400)),
            ContentPart.image("data", "image/png")
          ]
        }
      ]

      assert TokenBudget.estimate_tokens(messages) == 4100
    end
  end

  describe "run/2" do
    test "passes through when under budget" do
      messages = [
        %Message{role: :user, content: [ContentPart.text("hello")]}
      ]

      result = TokenBudget.run(messages, token_budget: 1_000_000)
      assert result == messages
    end

    test "strategy 1: aggressive image decay removes old images" do
      old_img = %Message{
        role: :user,
        content: [ContentPart.text("look"), ContentPart.image("data", "image/png")]
      }

      assistant = %Message{role: :assistant, content: [ContentPart.text("ok")]}

      live_img = %Message{
        role: :user,
        content: [ContentPart.text("now"), ContentPart.image("data2", "image/png")]
      }

      messages = [old_img, assistant, live_img]

      # Budget that fits text + 1 image but not 2 (text ~12 tokens, 2 images = 8000)
      result = TokenBudget.run(messages, token_budget: 5000)

      # Old image should be removed, live image kept
      old_content = Enum.at(result, 0).content
      refute Enum.any?(old_content, &(&1.type == :image))

      live_content = Enum.at(result, 2).content
      assert Enum.any?(live_content, &(&1.type == :image))
    end

    test "strategy 2: truncates old tool results" do
      big_json = String.duplicate("x", 4000)

      messages = [
        %Message{role: :tool, content: [ContentPart.text(big_json)], tool_call_id: "tc1"},
        %Message{role: :assistant, content: [ContentPart.text("ok")]},
        %Message{role: :user, content: [ContentPart.text("continue")]}
      ]

      # Budget too small for the full tool result
      result = TokenBudget.run(messages, token_budget: 200, budget_truncation_length: 100)

      tool_text = Enum.at(result, 0).content |> hd() |> Map.get(:text)
      assert String.ends_with?(tool_text, "[truncated]")
      assert byte_size(tool_text) < 4000
    end

    test "strategy 3: drops oldest turns keeping system + recent" do
      system = %Message{role: :system, content: [ContentPart.text("system prompt")]}

      old_turns =
        for i <- 1..20 do
          [
            %Message{role: :user, content: [ContentPart.text(String.duplicate("msg#{i} ", 200))]},
            %Message{role: :assistant, content: [ContentPart.text(String.duplicate("resp#{i} ", 200))]}
          ]
        end
        |> List.flatten()

      messages = [system | old_turns]

      result =
        TokenBudget.run(messages,
          token_budget: 500,
          budget_truncation_length: 50,
          budget_keep_recent_turns: 3
        )

      # System message preserved
      assert hd(result).role == :system

      # 3 recent turns (each = user + assistant = 2 messages) + 1 system = 7
      assert length(result) == 7
    end

    test "strategy 3: turn counting includes tool messages" do
      system = %Message{role: :system, content: [ContentPart.text("system prompt")]}

      # Each turn: user -> assistant (with tool call) -> tool -> assistant
      turns =
        for i <- 1..5 do
          [
            %Message{role: :user, content: [ContentPart.text(String.duplicate("q#{i} ", 200))]},
            %Message{
              role: :assistant,
              content: nil,
              tool_calls: [%{id: "tc#{i}", function: %{name: "read", arguments: "{}"}}]
            },
            %Message{role: :tool, content: [ContentPart.text(String.duplicate("r#{i} ", 200))], tool_call_id: "tc#{i}"},
            %Message{role: :assistant, content: [ContentPart.text(String.duplicate("a#{i} ", 200))]}
          ]
        end
        |> List.flatten()

      messages = [system | turns]

      result =
        TokenBudget.run(messages,
          token_budget: 500,
          budget_truncation_length: 50,
          budget_keep_recent_turns: 2
        )

      assert hd(result).role == :system

      # 2 turns, each with 4 messages (user + assistant + tool + assistant) + 1 system
      non_system = Enum.reject(result, &(&1.role == :system))
      assert length(non_system) == 8
    end
  end
end
