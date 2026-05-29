defmodule SwarmAi.MaxTokensTruncationTest do
  use SwarmAi.Testing, async: true

  alias ReqLLM.StreamChunk
  alias SwarmAi.LLM.Response

  describe "max_tokens truncation during tool call" do
    test "Response.from_stream with :length and pending tool calls returns :length finish_reason" do
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
      assert tc.arguments == "{\"path\": \"foo.md\", \"content\": \"# Title\\n\\nSome long con"
    end
  end
end
