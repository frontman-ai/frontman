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
      assert tool.on_timeout == :error
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

    test "applies pause_agent policy for executionMode: Interactive" do
      tool =
        MCP.from_map(%{
          "name" => "question",
          "description" => "Ask user a question",
          "inputSchema" => %{},
          "_meta" => %{
            "ai.frontman/tool-metadata" => %{"executionMode" => "Interactive"}
          }
        })

      assert tool.timeout_ms == 120_000
      assert tool.on_timeout == :pause_agent
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

    test "passes pause_agent policy through to swarm tool for interactive tools" do
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

      assert swarm_tool.timeout_ms == 120_000
      assert swarm_tool.on_timeout == :pause_agent
    end
  end
end
