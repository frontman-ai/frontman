defmodule SwarmAi.LLM.ResponseTest do
  use ExUnit.Case, async: true

  alias SwarmAi.LLM.{Chunk, Response}

  describe "from_stream/1 finish_reason" do
    test "preserves :length finish_reason when followed by :stop done chunk" do
      stream = [
        Chunk.token("partial content"),
        Chunk.done(:length),
        Chunk.done(:stop)
      ]

      response = Response.from_stream(stream)

      assert response.finish_reason == :length
    end

    test ":stop finish_reason is preserved when no prior terminal reason" do
      stream = [
        Chunk.token("hello"),
        Chunk.done(:stop)
      ]

      response = Response.from_stream(stream)

      assert response.finish_reason == :stop
    end

    test ":tool_calls finish_reason is preserved over subsequent :stop" do
      stream = [
        Chunk.tool_call_start("tc_1", "read_file", 0),
        Chunk.tool_call_args(0, "{\"path\": \"foo.txt\"}"),
        Chunk.done(:tool_calls),
        Chunk.done(:stop)
      ]

      response = Response.from_stream(stream)

      assert response.finish_reason == :tool_calls
    end
  end
end
