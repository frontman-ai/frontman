defmodule FrontmanServer.Tools.MCPTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tools.MCP

  describe "from_map/1" do
    test "preserves standard MCP tool fields and annotations" do
      tool =
        MCP.from_map(%{
          "name" => "navigate",
          "title" => "Navigate",
          "description" => "Navigate to a URL",
          "inputSchema" => %{"type" => "object"},
          "outputSchema" => %{"type" => "object"},
          "icons" => [%{"src" => "https://example.com/icon.png"}],
          "annotations" => %{"readOnlyHint" => true, "vendorHint" => "preserved"},
          "_meta" => %{"vendor.example/tool" => true}
        })

      assert tool.name == "navigate"
      assert tool.title == "Navigate"
      assert tool.description == "Navigate to a URL"
      assert tool.input_schema == %{"type" => "object"}
      assert tool.output_schema == %{"type" => "object"}
      assert tool.icons == [%{"src" => "https://example.com/icon.png"}]
      assert tool.annotations == %{"readOnlyHint" => true, "vendorHint" => "preserved"}
      assert tool.meta == %{"vendor.example/tool" => true}
    end

    test "does not derive internal policy from nonstandard wire fields" do
      tool =
        MCP.from_map(%{
          "name" => "question",
          "inputSchema" => %{"type" => "object"},
          "executionMode" => "interactive",
          "access" => "read",
          "visibleToAgent" => false,
          "timeoutMs" => 1,
          "onTimeout" => "pause_agent"
        })

      assert tool.access == :read_write
      assert tool.visible_to_agent
      assert tool.timeout_ms == 600_000
      assert tool.on_timeout == :error
    end
  end

  describe "to_swarm_tools/1" do
    test "uses conservative internal execution policy" do
      mcp_tool =
        MCP.from_map(%{
          "name" => "read_file",
          "description" => "Read file",
          "inputSchema" => %{"type" => "object"},
          "annotations" => %{"readOnlyHint" => true}
        })

      assert [swarm_tool] = MCP.to_swarm_tools([mcp_tool])
      assert swarm_tool.access == :read_write
      assert swarm_tool.timeout_ms == 600_000
      assert swarm_tool.on_timeout == :error
    end
  end
end
