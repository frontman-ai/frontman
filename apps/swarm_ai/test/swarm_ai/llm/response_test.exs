defmodule SwarmAi.LLM.ResponseTest do
  use ExUnit.Case, async: true

  alias ReqLLM.StreamChunk
  alias SwarmAi.LLM.Response

  describe "from_stream/1 usage" do
    test "preserves full usage metadata" do
      usage = %{
        input_tokens: 100,
        output_tokens: 50,
        total_tokens: 175,
        cache_creation_tokens: 10,
        tool_usage: %{"web_search" => 2},
        image_usage: %{"input_images" => 1}
      }

      stream = [
        StreamChunk.text("hello"),
        StreamChunk.meta(%{usage: usage}),
        StreamChunk.meta(%{finish_reason: :stop})
      ]

      response = Response.from_stream(stream)

      assert response.usage == usage
    end
  end

  describe "from_stream/1 finish_reason" do
    test "preserves :length finish_reason when followed by :stop done chunk" do
      stream = [
        StreamChunk.text("partial content"),
        StreamChunk.meta(%{finish_reason: :length}),
        StreamChunk.meta(%{finish_reason: :stop})
      ]

      response = Response.from_stream(stream)

      assert response.finish_reason == :length
    end

    test ":stop finish_reason is preserved when no prior terminal reason" do
      stream = [
        StreamChunk.text("hello"),
        StreamChunk.meta(%{finish_reason: :stop})
      ]

      response = Response.from_stream(stream)

      assert response.finish_reason == :stop
    end

    test ":tool_calls finish_reason is preserved over subsequent :stop" do
      stream = [
        StreamChunk.tool_call("read_file", %{}, %{id: "tc_1", index: 0}),
        StreamChunk.meta(%{tool_call_args: %{index: 0, fragment: "{\"path\": \"foo.txt\"}"}}),
        StreamChunk.meta(%{finish_reason: :tool_calls}),
        StreamChunk.meta(%{finish_reason: :stop})
      ]

      response = Response.from_stream(stream)

      assert response.finish_reason == :tool_calls
    end

    test "normalizes provider atom finish reasons to canonical values" do
      stream = [
        StreamChunk.text("hello"),
        StreamChunk.meta(%{finish_reason: :end_turn}),
        StreamChunk.meta(%{finish_reason: :stop})
      ]

      response = Response.from_stream(stream)

      assert response.finish_reason == :stop
    end
  end
end
