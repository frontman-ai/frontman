defmodule FrontmanServer.Protocols.McpContractTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.ProtocolSchema

  describe "ModelContextProtocol.initialize_params/0" do
    test "validates against mcp/initializeParams schema" do
      payload = ModelContextProtocol.initialize_params()
      ProtocolSchema.validate!(payload, "mcp/initializeParams")
    end
  end

  describe "ModelContextProtocol.client_info/0" do
    test "validates against mcp/info schema" do
      payload = ModelContextProtocol.client_info()
      ProtocolSchema.validate!(payload, "mcp/info")
    end
  end

  describe "ModelContextProtocol.tools_call_request/1" do
    test "params field validates against mcp/toolCallParams schema" do
      request =
        ModelContextProtocol.tools_call_request(%ModelContextProtocol.ToolCallParams{
          request_id: 1,
          tool_name: "read_file",
          arguments: %{"path" => "/tmp/test.txt"},
          call_id: "call-123"
        })

      # The request is a JSON-RPC envelope; validate the params field
      ProtocolSchema.validate!(request["params"], "mcp/toolCallParams")
    end

    test "full request validates against jsonrpc/request schema" do
      request =
        ModelContextProtocol.tools_call_request(%ModelContextProtocol.ToolCallParams{
          request_id: 42,
          tool_name: "search_files",
          arguments: %{"query" => "test"},
          call_id: "call-456"
        })

      ProtocolSchema.validate!(request, "jsonrpc/request")
    end
  end
end
