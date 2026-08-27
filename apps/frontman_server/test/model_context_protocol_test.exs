defmodule ModelContextProtocolTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias ModelContextProtocol, as: MCP

  test "builds required MCP 2026 request metadata" do
    meta = MCP.request_params()["_meta"]

    assert meta["io.modelcontextprotocol/protocolVersion"] == "2026-07-28"

    assert get_in(meta, ["io.modelcontextprotocol/clientCapabilities", "extensions"]) ==
             %{
               "ai.frontman/execution-context" => %{"version" => 1},
               "ai.frontman/tool-metadata" => %{"version" => 1}
             }

    assert meta["io.modelcontextprotocol/clientInfo"] ==
             %{"name" => "frontman-server", "version" => "1.0.0"}
  end

  test "builds tools/list pagination params" do
    refute Map.has_key?(MCP.tools_list_params(), "cursor")
    assert MCP.tools_list_params("page-2")["cursor"] == "page-2"
  end

  test "builds tools/call with execution context only in metadata" do
    previous_level = Logger.level()
    Logger.configure(level: :info)

    log =
      capture_log(fn ->
        request =
          MCP.build_tool_execution(%MCP.ToolCallParams{
            request_id: 789,
            tool_name: "search_files",
            arguments: %{"secret" => "private-value"},
            task_id: "task-1",
            call_id: "call-789"
          })

        send(self(), {:request, request})
      end)

    Logger.configure(level: previous_level)

    assert_received {:request, request}
    assert request["method"] == "tools/call"
    assert request["params"]["name"] == "search_files"
    refute Map.has_key?(request["params"], "callId")

    assert request["params"]["_meta"]["ai.frontman/execution-context"] == %{
             "taskId" => "task-1",
             "callId" => "call-789"
           }

    assert log =~ "MCP tool call: search_files"
    refute log =~ "private-value"
  end
end
