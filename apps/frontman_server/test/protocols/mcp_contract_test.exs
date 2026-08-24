defmodule FrontmanServer.Protocols.McpContractTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.ProtocolSchema
  alias ModelContextProtocol, as: MCP

  test "discovery and tools/list params satisfy the shared contract" do
    ProtocolSchema.validate!(MCP.request_params(), "mcp/discoverParams")
    ProtocolSchema.validate!(MCP.request_params(), "mcp/toolsListParams")
  end

  test "tools/call params satisfy the shared contract" do
    request =
      MCP.build_tool_execution(%MCP.ToolCallParams{
        request_id: 123,
        tool_name: "read_file",
        arguments: %{"path" => "/tmp/test.txt"},
        task_id: "task-1",
        call_id: "call-123"
      })

    ProtocolSchema.validate!(request["params"], "mcp/toolCallParams")
    ProtocolSchema.validate!(request, "jsonrpc/request")
  end

  test "discovery result contract accepts core extensions" do
    ProtocolSchema.validate!(
      %{
        "resultType" => "complete",
        "supportedVersions" => ["2026-07-28", "2027-01-01"],
        "capabilities" => %{"tools" => %{}, "logging" => %{}},
        "instructions" => "Use tools carefully",
        "ttlMs" => 0.5,
        "cacheScope" => "public"
      },
      "mcp/discoverResult"
    )
  end

  test "tools/list result contract accepts optional pagination and metadata" do
    ProtocolSchema.validate!(
      %{
        "resultType" => "complete",
        "tools" => [
          %{
            "name" => "search",
            "title" => "Search",
            "inputSchema" => %{"type" => "object"}
          }
        ],
        "nextCursor" => "opaque",
        "ttlMs" => 1.5,
        "cacheScope" => "public"
      },
      "mcp/toolsListResult"
    )
  end
end
