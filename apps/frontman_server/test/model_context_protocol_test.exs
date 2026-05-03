defmodule ModelContextProtocolTest do
  use ExUnit.Case, async: true

  describe "initialize_params/0" do
    test "returns params for MCP initialize request" do
      params = ModelContextProtocol.initialize_params()

      assert params["protocolVersion"] == "DRAFT-2025-v3"
      assert params["capabilities"] == %{}
      assert params["clientInfo"]["name"] == "frontman-server"
      assert params["clientInfo"]["version"] == "1.0.0"
    end
  end

  describe "protocol_version/0" do
    test "returns the MCP protocol version" do
      assert ModelContextProtocol.protocol_version() == "DRAFT-2025-v3"
    end
  end

  describe "client_info/0" do
    test "returns client info map" do
      info = ModelContextProtocol.client_info()

      assert info["name"] == "frontman-server"
      assert info["version"] == "1.0.0"
    end
  end

  describe "build_tool_execution/1" do
    import ExUnit.CaptureLog

    test "returns {request_id, request} tuple with valid JSON-RPC structure" do
      params = %ModelContextProtocol.ToolCallParams{
        tool_name: "search_files",
        arguments: %{"query" => "test"},
        call_id: "call-789"
      }

      {request_id, request} = ModelContextProtocol.build_tool_execution(params)

      assert is_integer(request_id)
      assert request["id"] == request_id
      assert request["jsonrpc"] == "2.0"
      assert request["method"] == "tools/call"
      assert request["params"]["name"] == "search_files"
      assert request["params"]["arguments"] == %{"query" => "test"}
      assert request["params"]["callId"] == "call-789"
    end

    test "generates unique request IDs" do
      params = %ModelContextProtocol.ToolCallParams{
        tool_name: "read_file",
        arguments: %{"path" => "/tmp/test.txt"},
        call_id: "call-1"
      }

      {id1, _} = ModelContextProtocol.build_tool_execution(params)
      {id2, _} = ModelContextProtocol.build_tool_execution(params)

      assert id1 != id2
    end

    @tag capture_log: true
    test "logs tool calls" do
      prev_level = Logger.level()
      Logger.configure(level: :info)

      params = %ModelContextProtocol.ToolCallParams{
        tool_name: "read_file",
        arguments: %{"path" => "/tmp/test.txt"},
        call_id: "call-log-1"
      }

      log =
        capture_log(fn ->
          ModelContextProtocol.build_tool_execution(params)
        end)

      Logger.configure(level: prev_level)

      assert log =~ "MCP tool call: read_file"
    end
  end
end
