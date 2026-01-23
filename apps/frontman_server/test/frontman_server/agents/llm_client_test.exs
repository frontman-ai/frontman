defmodule FrontmanServer.Agents.LLMClientTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents.LLMClient

  describe "to_reqllm_tool/3" do
    setup do
      tool = %Swarm.Tool{
        name: "read_file",
        description: "Reads a file",
        parameter_schema: %{
          "type" => "object",
          "properties" => %{
            "path" => %{"type" => "string"}
          },
          "required" => ["path"]
        }
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
