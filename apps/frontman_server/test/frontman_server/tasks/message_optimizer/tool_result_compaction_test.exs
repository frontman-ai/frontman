defmodule FrontmanServer.Tasks.MessageOptimizer.ToolResultCompactionTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.MessageOptimizer.ToolResultCompaction
  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  describe "run/3" do
    test "strips configured keys from old tool result JSON" do
      json =
        Jason.encode!(%{
          "content" => "file contents here",
          "start_line" => 1,
          "lines_returned" => 50,
          "total_lines" => 200
        })

      messages = [
        %Message{role: :tool, content: [ContentPart.text(json)], tool_call_id: "tc1"},
        %Message{role: :assistant, content: [ContentPart.text("got it")]},
        %Message{role: :tool, content: [ContentPart.text(json)], tool_call_id: "tc2"}
      ]

      result = ToolResultCompaction.run(messages, 2)

      # Old tool message: keys stripped
      old_text = Enum.at(result, 0).content |> hd() |> Map.get(:text)
      decoded = Jason.decode!(old_text)
      assert decoded == %{"content" => "file contents here"}

      # Live tool message: untouched
      live_text = Enum.at(result, 2).content |> hd() |> Map.get(:text)
      assert Jason.decode!(live_text) == Jason.decode!(json)
    end

    test "leaves non-JSON text content alone" do
      messages = [
        %Message{role: :tool, content: [ContentPart.text("plain text result")], tool_call_id: "tc1"},
        %Message{role: :assistant, content: [ContentPart.text("ok")]}
      ]

      result = ToolResultCompaction.run(messages, 2)
      assert Enum.at(result, 0).content |> hd() |> Map.get(:text) == "plain text result"
    end

    test "accepts custom strip keys via opts" do
      json = Jason.encode!(%{"keep" => "yes", "remove_me" => "gone"})

      messages = [
        %Message{role: :tool, content: [ContentPart.text(json)], tool_call_id: "tc1"},
        %Message{role: :assistant, content: [ContentPart.text("ok")]}
      ]

      result = ToolResultCompaction.run(messages, 2, tool_result_strip_keys: ["remove_me"])

      decoded = Enum.at(result, 0).content |> hd() |> Map.get(:text) |> Jason.decode!()
      assert decoded == %{"keep" => "yes"}
    end

    test "skips non-tool messages even if old" do
      messages = [
        %Message{role: :user, content: [ContentPart.text(Jason.encode!(%{"start_line" => 1}))]},
        %Message{role: :assistant, content: [ContentPart.text("ok")]}
      ]

      result = ToolResultCompaction.run(messages, 2)
      assert result == messages
    end
  end
end
