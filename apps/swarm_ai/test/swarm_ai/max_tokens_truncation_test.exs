defmodule SwarmAi.MaxTokensTruncationTest do
  @moduledoc """
  Tests that when the LLM response is truncated by max_tokens (finish_reason: :length)
  during a tool call, the error is caught and surfaced as a graceful failure.
  """

  use SwarmAi.Testing, async: true

  alias ReqLLM.StreamChunk
  alias SwarmAi.LLM.{Response, Usage}

  describe "max_tokens truncation during tool call" do
    test "Response.from_stream with :length and pending tool calls returns :length finish_reason" do
      # Simulates max_tokens hit mid-tool-use: tool call started, partial JSON, then :length
      stream = [
        StreamChunk.tool_call("write_file", %{}, %{id: "tc_1", index: 0}),
        StreamChunk.meta(%{
          tool_call_args: %{
            index: 0,
            fragment: "{\"path\": \"foo.md\", \"content\": \"# Title\\n\\nSome long con"
          }
        }),
        StreamChunk.meta(%{usage: %{input_tokens: 1000, output_tokens: 16_384}}),
        StreamChunk.meta(%{finish_reason: :length})
      ]

      response = Response.from_stream(stream)

      assert response.finish_reason == :length
      assert length(response.tool_calls) == 1

      [tc] = response.tool_calls
      # The JSON is truncated — not valid
      assert tc.arguments == "{\"path\": \"foo.md\", \"content\": \"# Title\\n\\nSome long con"
    end

    test "run_streaming fails gracefully when LLM truncates tool call" do
      # Use a MockLLM that returns a response with :length and a truncated tool call
      truncated_tc = %SwarmAi.ToolCall{
        id: "tc_trunc",
        name: "write_file",
        arguments: "{\"path\": \"foo.md\", \"content\": \"truncated..."
      }

      llm =
        mock_llm(
          {:ok,
           %SwarmAi.LLM.Response{
             content: "",
             tool_calls: [truncated_tc],
             finish_reason: :length,
             usage: %Usage{input_tokens: 1000, output_tokens: 16_384}
           }}
        )

      agent = test_agent(llm, "TruncationTestAgent")

      result =
        SwarmAi.run_blocking(agent, "Write a long file", fn _tc ->
          {:error, "should not be called — truncated tool call"}
        end)

      # The loop should detect :length + tool calls and fail, not execute the broken tool
      assert {:error, reason, _loop_id} = result
      assert reason == :output_truncated
    end
  end
end
