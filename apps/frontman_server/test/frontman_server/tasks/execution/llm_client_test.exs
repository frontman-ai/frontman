defmodule FrontmanServer.Tasks.Execution.LLMClientTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.LLMClient
  alias ReqLLM.Error.API.{Request, Stream}

  describe "ReqLLM stream exception contract" do
    test "ReqLLM.Error.API.Stream carries ReqLLM.Error.API.Request as cause" do
      request_error =
        Request.exception(
          status: 400,
          reason: "image exceeds the maximum allowed size"
        )

      stream_error = Stream.exception(reason: "Stream failed", cause: request_error)

      assert %Request{} = stream_error.cause
      assert stream_error.cause.status == 400
      assert stream_error.cause.reason == "image exceeds the maximum allowed size"
    end
  end

  describe "to_reqllm_tool/3" do
    setup do
      tool = %SwarmAi.Tool{
        name: "read_file",
        description: "Reads a file",
        parameter_schema: %{
          "type" => "object",
          "properties" => %{
            "path" => %{"type" => "string"}
          },
          "required" => ["path"]
        },
        timeout_ms: 60_000,
        on_timeout: :error
      }

      {:ok, tool: tool}
    end

    test "without anthropic_oauth does not prefix tool name", %{tool: tool} do
      result = LLMClient.to_reqllm_tool(tool, "anthropic:claude-sonnet-4-20250514", [])

      assert result.name == "read_file"
    end

    test "preserves description and schema", %{tool: tool} do
      result = LLMClient.to_reqllm_tool(tool, "anthropic:claude-sonnet-4-20250514")

      assert result.description == "Reads a file"
      assert result.parameter_schema["properties"]["path"]["type"] == "string"
    end
  end

  describe "ping keepalive filtering (issue #731)" do
    test "ping meta chunks from ReqLLM are metadata-only chunks" do
      ping_chunk = ReqLLM.StreamChunk.meta(%{ping: true})

      assert ping_chunk.type == :meta
      refute Map.has_key?(ping_chunk.metadata, :usage)
      refute Map.has_key?(ping_chunk.metadata, :finish_reason)
      refute Map.has_key?(ping_chunk.metadata, :tool_call_args)
      refute Map.has_key?(ping_chunk.metadata, :terminal?)
    end

    test "ping meta chunk is distinguishable from other meta chunks" do
      ping = ReqLLM.StreamChunk.meta(%{ping: true})
      usage = ReqLLM.StreamChunk.meta(%{usage: %{input_tokens: 10, output_tokens: 5}})
      finish = ReqLLM.StreamChunk.meta(%{finish_reason: :stop})

      assert ping.metadata.ping == true
      refute Map.has_key?(usage.metadata, :ping)
      refute Map.has_key?(finish.metadata, :ping)
    end
  end
end
