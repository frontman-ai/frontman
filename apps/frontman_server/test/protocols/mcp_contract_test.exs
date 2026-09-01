defmodule FrontmanServer.Protocols.McpContractTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.ProtocolSchema
  alias ModelContextProtocol, as: MCP

  test "discovery request validates against the modern generated schema" do
    MCP.discover_request("discover-1")
    |> ProtocolSchema.validate!("mcp/discoverRequest")
  end

  test "list request validates against the modern generated schema" do
    MCP.list_tools_request(2)
    |> ProtocolSchema.validate!("mcp/listToolsRequest")
  end

  test "client info validates as an implementation" do
    MCP.client_info()
    |> ProtocolSchema.validate!("mcp/implementation")
  end

  test "tools/call request and execution metadata validate" do
    request =
      MCP.build_tool_execution(%MCP.ToolCallParams{
        request_id: 3,
        task_id: "task-1",
        tool_name: "read_file",
        arguments: %{"path" => "/tmp/test.txt"},
        tool_call_id: "tool-call-3"
      })

    ProtocolSchema.validate!(request, "mcp/callToolRequest")
    ProtocolSchema.validate!(request["params"], "mcp/callToolRequestParams")
    ProtocolSchema.validate!(request["params"]["_meta"], "mcp/executionContextRequestMeta")
  end

  test "all result constructors validate against callToolResult" do
    for result <- [
          MCP.tool_result_text("ok"),
          MCP.tool_result_json(false),
          MCP.tool_result_image("aW1hZ2U=", "image/png"),
          MCP.tool_result_error("failed")
        ] do
      ProtocolSchema.validate!(result, "mcp/callToolResult")
    end
  end
end
