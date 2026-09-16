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
end
