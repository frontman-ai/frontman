defmodule FrontmanServer.Tools.GetToolResultPagingTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Tasks.Execution.LLMRequestPreflight
  alias FrontmanServer.Tasks.Interaction.ToolResult
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tools.Backend.Context
  alias FrontmanServer.Tools.GetToolResult
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  defp context(text) do
    result = %{"content" => [%{"type" => "text", "text" => text}], "isError" => true}
    row = %InteractionSchema{data: %ToolResult{tool_call_id: "source", result: result}}
    %Context{task: %{interaction_rows: [row]}}
  end

  test "pages reconstruct large UTF-8 output and survive preflight truncation" do
    text = String.duplicate("abc😀\n\"", 10_000)
    context = context(text)

    {chunks, offset} =
      Enum.reduce(1..20, {[], 0}, fn
        _, {chunks, nil} ->
          {chunks, nil}

        _, {chunks, offset} ->
          result =
            GetToolResult.execute(%{"tool_call_id" => "source", "offset" => offset}, context)

          assert MCP.error?(result)
          payload = MCP.extract_content_text(result)
          assert byte_size(payload) < 51_200
          page = Jason.decode!(payload)
          assert String.valid?(page["text"])
          assert page["content_count"] == 1
          assert page["total_bytes"] == byte_size(text)

          message = %Message.Tool{
            name: "get_tool_result",
            tool_call_id: "paged",
            content: [ContentPart.text(payload)]
          }

          assert [^message] = LLMRequestPreflight.run([message])
          {[page["text"] | chunks], page["next_offset"]}
      end)

    assert offset == nil
    assert chunks |> Enum.reverse() |> Enum.join() == text
  end

  test "escaped control characters stay below the default preflight limit" do
    result =
      GetToolResult.execute(
        %{"tool_call_id" => "source", "offset" => 0},
        context(String.duplicate(<<0>>, 9000))
      )

    payload = MCP.extract_content_text(result)
    assert byte_size(payload) < 51_200
    assert %{"next_offset" => 8000} = Jason.decode!(payload)
  end

  test "validates paging bounds, content selection, and UTF-8 offsets" do
    context = context("😀abcdef")

    for args <- [
          %{"offset" => -1},
          %{"offset" => 99},
          %{"offset" => 1},
          %{"limit" => 3},
          %{"limit" => 8001},
          %{"limit" => "4"},
          %{"content_index" => 1}
        ] do
      result = GetToolResult.execute(Map.put(args, "tool_call_id", "source"), context)
      assert MCP.error?(result)
      refute MCP.extract_content_text(result) =~ "next_offset"
    end

    result = GetToolResult.execute(%{"tool_call_id" => "source", "offset" => 10}, context)

    assert %{"text" => "", "next_offset" => nil} =
             result |> MCP.extract_content_text() |> Jason.decode!()
  end
end
