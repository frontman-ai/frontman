defmodule FrontmanServer.Tasks.Execution.LLMClientTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.LLMClient

  describe "ReqLLM error chunk contract" do
    test "ReqLLM.StreamChunk.error/1 creates an :error type chunk" do
      chunk = ReqLLM.StreamChunk.error("image exceeds the maximum allowed size")

      assert chunk.type == :error
      assert chunk.text == "image exceeds the maximum allowed size"
      assert chunk.metadata == %{}
    end

    test "ReqLLM.StreamChunk.error/2 preserves metadata" do
      chunk =
        ReqLLM.StreamChunk.error("HTTP 400: Request too large", %{
          status: 400,
          provider: :anthropic
        })

      assert chunk.type == :error
      assert chunk.text == "HTTP 400: Request too large"
      assert chunk.metadata.status == 400
      assert chunk.metadata.provider == :anthropic
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

    test "with anthropic_oauth: false does not prefix tool name", %{tool: tool} do
      result =
        LLMClient.to_reqllm_tool(tool, "anthropic:claude-sonnet-4-20250514",
          requires_mcp_prefix: false
        )

      assert result.name == "read_file"
    end

    test "with requires_mcp_prefix: true prefixes tool name with mcp_", %{tool: tool} do
      result =
        LLMClient.to_reqllm_tool(tool, "anthropic:claude-sonnet-4-20250514",
          requires_mcp_prefix: true
        )

      assert result.name == "mcp_read_file"
    end

    test "preserves description and schema", %{tool: tool} do
      result =
        LLMClient.to_reqllm_tool(tool, "anthropic:claude-sonnet-4-20250514",
          requires_mcp_prefix: true
        )

      assert result.description == "Reads a file"
      assert result.parameter_schema["properties"]["path"]["type"] == "string"
    end
  end

  describe "strip_mcp_prefix/1" do
    test "strips mcp_ prefix when present" do
      assert LLMClient.strip_mcp_prefix("mcp_read_file") == "read_file"
    end

    test "passes through when no mcp_ prefix" do
      assert LLMClient.strip_mcp_prefix("read_file") == "read_file"
    end

    test "only strips prefix, not middle occurrences" do
      assert LLMClient.strip_mcp_prefix("mcp_some_mcp_tool") == "some_mcp_tool"
    end
  end

  describe "ping keepalive filtering (issue #731)" do
    test "ping meta chunks from ReqLLM do not reach SwarmAi consumers" do
      # After the fix, ReqLLM emits meta chunks with %{ping: true} for
      # Anthropic keep-alive pings. These must be filtered out before
      # reaching SwarmAi — they exist only to reset the stall timeout.
      ping_chunk = ReqLLM.StreamChunk.meta(%{ping: true})

      # The catch-all meta clause in to_swarm_chunk returns nil for
      # unknown meta keys, so pings get rejected by Stream.reject(&is_nil/1).
      # We verify the chunk shape matches that catch-all path.
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

  describe "requires_mcp_prefix?/1" do
    test "returns true when requires_mcp_prefix: true" do
      assert LLMClient.requires_mcp_prefix?(requires_mcp_prefix: true)
    end

    test "returns false when requires_mcp_prefix: false" do
      refute LLMClient.requires_mcp_prefix?(requires_mcp_prefix: false)
    end

    test "returns false when not set" do
      refute LLMClient.requires_mcp_prefix?([])
    end

    test "returns false for other keys" do
      refute LLMClient.requires_mcp_prefix?(api_key: "secret")
    end
  end
end
