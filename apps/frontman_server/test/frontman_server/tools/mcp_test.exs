defmodule FrontmanServer.Tools.MCPTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tools.MCP

  describe "from_map/1" do
    test "parses standard MCP tool fields" do
      output_schema = %{"type" => "object"}

      tool =
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate to a URL",
          "inputSchema" => %{},
          "outputSchema" => output_schema
        })

      assert tool.name == "navigate"
      assert tool.description == "Navigate to a URL"
      assert tool.access == :read_write
      assert tool.output_schema == output_schema
      assert tool.timeout_ms == 600_000
      assert tool.execution_mode == :synchronous
    end

    test "parses access from wire format" do
      for {wire, expected} <- [
            {"read", :read},
            {"write", :write},
            {"read-write", :read_write},
            {"bogus", :read_write}
          ] do
        tool =
          MCP.from_map(%{
            "name" => "test_tool",
            "description" => "Test tool",
            "inputSchema" => %{},
            "_meta" => %{"ai.frontman/tool-metadata" => %{"access" => wire}}
          })

        assert tool.access == expected
      end
    end

    test "interactive tools have no deadline" do
      tool =
        MCP.from_map(%{
          "name" => "question",
          "description" => "Ask user a question",
          "inputSchema" => %{},
          "_meta" => %{
            "ai.frontman/tool-metadata" => %{"executionMode" => "Interactive"}
          }
        })

      assert tool.timeout_ms == :infinity
      assert tool.execution_mode == :interactive
    end
  end

  test "rejects unsupported declared execution modes" do
    for mode <- ["interactive", "Unknown", 1, false] do
      assert_raise FunctionClauseError, fn ->
        MCP.from_map(%{
          "name" => "approval",
          "_meta" => %{"ai.frontman/tool-metadata" => %{"executionMode" => mode}}
        })
      end
    end
  end

  describe "to_swarm_tools/1" do
    test "passes access through to swarm tool" do
      mcp_tool =
        MCP.from_map(%{
          "name" => "read_file",
          "description" => "Read file",
          "inputSchema" => %{},
          "_meta" => %{"ai.frontman/tool-metadata" => %{"access" => "read"}}
        })

      [swarm_tool] = MCP.to_swarm_tools([mcp_tool])

      assert swarm_tool.access == :read
    end

    test "model-facing tools carry no operational deadline" do
      mcp_tool =
        MCP.from_map(%{
          "name" => "question",
          "description" => "Ask user",
          "inputSchema" => %{},
          "_meta" => %{
            "ai.frontman/tool-metadata" => %{"executionMode" => "Interactive"}
          }
        })

      [swarm_tool] = MCP.to_swarm_tools([mcp_tool])

      refute Map.has_key?(swarm_tool, :timeout_ms)
      refute Map.has_key?(swarm_tool, :on_timeout)
    end
  end
end
