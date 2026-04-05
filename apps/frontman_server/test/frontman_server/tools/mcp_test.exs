defmodule FrontmanServer.Tools.MCPTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tools.MCP

  describe "from_map/1" do
    test "parses standard MCP tool fields" do
      tool =
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate to a URL",
          "inputSchema" => %{}
        })

      assert tool.name == "navigate"
      assert tool.description == "Navigate to a URL"
    end

    test "applies server-side timeout defaults" do
      tool =
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate to a URL",
          "inputSchema" => %{}
        })

      assert tool.timeout_ms == 600_000
      assert tool.on_timeout == :error
    end

    test "does not require or read timeoutMs / onTimeout from wire" do
      # Tools from external MCP servers don't include these fields — they
      # must not be required.
      assert %MCP{} =
               MCP.from_map(%{
                 "name" => "take_screenshot",
                 "description" => "Screenshot",
                 "inputSchema" => %{}
               })
    end

    test "applies pause_agent policy for executionMode: interactive" do
      tool =
        MCP.from_map(%{
          "name" => "question",
          "description" => "Ask user a question",
          "inputSchema" => %{},
          "executionMode" => "interactive"
        })

      assert tool.timeout_ms == 120_000
      assert tool.on_timeout == :pause_agent
    end

    test "keeps default timeout policy for executionMode: synchronous" do
      tool =
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate to a URL",
          "inputSchema" => %{},
          "executionMode" => "synchronous"
        })

      assert tool.timeout_ms == 600_000
      assert tool.on_timeout == :error
    end

    test "keeps default timeout policy when executionMode is absent" do
      tool =
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate to a URL",
          "inputSchema" => %{}
        })

      assert tool.timeout_ms == 600_000
      assert tool.on_timeout == :error
    end
  end

  describe "to_swarm_tools/1" do
    test "passes default timeout policy through to swarm tool" do
      mcp_tool =
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate to a URL",
          "inputSchema" => %{},
          "visibleToAgent" => true
        })

      [swarm_tool] = MCP.to_swarm_tools([mcp_tool])

      assert swarm_tool.timeout_ms == 600_000
      assert swarm_tool.on_timeout == :error
    end

    test "passes pause_agent policy through to swarm tool for interactive tools" do
      mcp_tool =
        MCP.from_map(%{
          "name" => "question",
          "description" => "Ask user",
          "inputSchema" => %{},
          "executionMode" => "interactive"
        })

      [swarm_tool] = MCP.to_swarm_tools([mcp_tool])

      assert swarm_tool.timeout_ms == 120_000
      assert swarm_tool.on_timeout == :pause_agent
    end
  end
end
