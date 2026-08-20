defmodule ModelContextProtocolTest do
  use ExUnit.Case, async: true

  alias ModelContextProtocol, as: MCP

  test "builds required MCP 2026 request metadata" do
    assert %{
             "_meta" => %{
               "io.modelcontextprotocol/protocolVersion" => "2026-07-28",
               "io.modelcontextprotocol/clientCapabilities" => %{
                 "extensions" => %{
                   "ai.frontman/execution-context" => %{"version" => 1}
                 }
               },
               "io.modelcontextprotocol/clientInfo" => %{
                 "name" => "frontman-server",
                 "version" => "1.0.0"
               }
             }
           } = MCP.request_params()
  end

  test "builds tools/call with execution context only in metadata" do
    request =
      MCP.build_tool_execution(%MCP.ToolCallParams{
        request_id: 789,
        tool_name: "search_files",
        arguments: %{"query" => "test"},
        task_id: "task-1",
        call_id: "call-789"
      })

    assert request["method"] == "tools/call"
    assert request["params"]["name"] == "search_files"
    refute Map.has_key?(request["params"], "callId")

    assert request["params"]["_meta"]["ai.frontman/execution-context"] == %{
             "taskId" => "task-1",
             "callId" => "call-789"
           }
  end

  test "terminal tool results are complete" do
    assert MCP.tool_result_text("ok")["resultType"] == "complete"
    assert MCP.tool_result_image("data", "image/png")["resultType"] == "complete"
    assert MCP.tool_result_error("bad")["resultType"] == "complete"
  end
end
