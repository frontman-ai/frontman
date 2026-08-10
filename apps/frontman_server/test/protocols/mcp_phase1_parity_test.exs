defmodule FrontmanServer.Protocols.McpPhase1ParityTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.ProtocolSchema
  alias ModelContextProtocol, as: MCP

  @fixture_path Path.expand(
                  "../../../../libs/frontman-protocol/test/fixtures/mcp-phase1-parity.json",
                  __DIR__
                )
  @fixtures @fixture_path |> File.read!() |> Jason.decode!()

  test "shared Phase 1 values validate against generated schemas" do
    for {fixture_name, schema_name} <- [
          {"discoverRequest", "mcp/discoverRequest"},
          {"discoverResult", "mcp/discoverResult"},
          {"listRequest", "mcp/listToolsRequest"},
          {"listResult", "mcp/listToolsResult"},
          {"callRequest", "mcp/callToolRequest"},
          {"completeResult", "mcp/callToolResult"},
          {"namedError", "mcp/unsupportedProtocolVersionError"},
          {"cancellation", "mcp/cancelledNotification"}
        ] do
      ProtocolSchema.validate!(@fixtures[fixture_name], schema_name)
    end
  end

  test "shared requests and cancellation equal Elixir runtime output" do
    assert MCP.discover_request("discover-1") == @fixtures["discoverRequest"]
    assert MCP.list_tools_request(2) == @fixtures["listRequest"]

    assert MCP.build_tool_execution(%MCP.ToolCallParams{
             request_id: "call-1",
             task_id: "task-1",
             tool_name: "read_file",
             arguments: %{"path" => "README.md"},
             tool_call_id: "tool-call-1"
           }) == @fixtures["callRequest"]

    assert MCP.cancelled_notification("call-1", "timeout") == @fixtures["cancellation"]
  end

  test "shared results and named error pass Elixir runtime parsing" do
    for {id, method, fixture_name} <- [
          {"discover-1", "server/discover", "discoverResult"},
          {2, "tools/list", "listResult"},
          {"call-1", "tools/call", "completeResult"}
        ] do
      result = @fixtures[fixture_name]
      response = %{"jsonrpc" => "2.0", "id" => id, "result" => result}
      assert {:ok, {:success, ^id, ^result}} = MCP.parse_response(response, method)
    end

    named_error = @fixtures["namedError"]
    assert {:ok, {:error, 4, error}} = MCP.parse_response(named_error)
    assert MCP.unsupported_protocol_version_error?(error)
  end
end
