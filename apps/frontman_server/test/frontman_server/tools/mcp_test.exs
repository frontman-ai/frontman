defmodule FrontmanServer.Tools.MCPTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tools.MCP

  describe "from_map/1" do
    test "parses timeout_ms and on_timeout from wire format" do
      tool =
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate to a URL",
          "inputSchema" => %{},
          "timeoutMs" => 30_000,
          "onTimeout" => "error"
        })

      assert tool.timeout_ms == 30_000
      assert tool.on_timeout == :error
    end

    test "parses on_timeout: pause_agent" do
      tool =
        MCP.from_map(%{
          "name" => "question",
          "description" => "Ask the user",
          "inputSchema" => %{},
          "timeoutMs" => 120_000,
          "onTimeout" => "pause_agent"
        })

      assert tool.on_timeout == :pause_agent
    end

    test "raises when timeoutMs is absent" do
      assert_raise KeyError, fn ->
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate",
          "inputSchema" => %{},
          "onTimeout" => "error"
        })
      end
    end

    test "raises when onTimeout is absent" do
      assert_raise KeyError, fn ->
        MCP.from_map(%{
          "name" => "navigate",
          "description" => "Navigate",
          "inputSchema" => %{},
          "timeoutMs" => 30_000
        })
      end
    end
  end

  describe "to_swarm_tools/1" do
    test "passes timeout_ms and on_timeout through without derivation" do
      mcp_tool =
        MCP.from_map(%{
          "name" => "question",
          "description" => "Ask user",
          "inputSchema" => %{},
          "timeoutMs" => 120_000,
          "onTimeout" => "pause_agent",
          "visibleToAgent" => true
        })

      [swarm_tool] = MCP.to_swarm_tools([mcp_tool])

      assert swarm_tool.timeout_ms == 120_000
      assert swarm_tool.on_timeout == :pause_agent
    end
  end
end
