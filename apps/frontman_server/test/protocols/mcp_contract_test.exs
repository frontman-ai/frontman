defmodule FrontmanServer.Protocols.McpContractTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.{Protocols.MCP, ProtocolSchema}

  test "discovery and tools/list params satisfy the shared contract" do
    params = MCP.request_params()

    assert params == %{
             "_meta" => %{
               "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
               "io.modelcontextprotocol/clientCapabilities" => %{
                 "extensions" => %{
                   "ai.frontman/execution-context" => %{"version" => 1},
                   "ai.frontman/tool-metadata" => %{"version" => 1}
                 }
               },
               "io.modelcontextprotocol/clientInfo" => %{
                 "name" => "frontman-server",
                 "version" => "1.0.0"
               }
             }
           }

    assert MCP.tools_list_params() == params
    assert MCP.tools_list_params("page-2") == Map.put(params, "cursor", "page-2")
    ProtocolSchema.validate!(params, "mcp/discoverParams")
    ProtocolSchema.validate!(MCP.tools_list_params(), "mcp/toolsListParams")
    ProtocolSchema.validate!(MCP.tools_list_params("page-2"), "mcp/toolsListParams")
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

    assert request["jsonrpc"] == "2.0"
    assert request["id"] == 123
    assert request["method"] == "tools/call"
    assert Map.keys(request["params"]) |> Enum.sort() == ["_meta", "arguments", "name"]
    assert request["params"]["name"] == "read_file"
    assert request["params"]["arguments"] == %{"path" => "/tmp/test.txt"}

    assert request["params"]["_meta"] ==
             Map.put(MCP.request_params()["_meta"], "ai.frontman/execution-context", %{
               "taskId" => "task-1",
               "callId" => "call-123"
             })

    ProtocolSchema.validate!(request["params"], "mcp/toolCallParams")
    ProtocolSchema.validate!(request, "jsonrpc/request")
  end
end
