defmodule ModelContextProtocolTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias ModelContextProtocol, as: MCP

  describe "modern requests" do
    test "builds discovery and list requests with required metadata" do
      for {request, method} <- [
            {MCP.discover_request("discover-1"), "server/discover"},
            {MCP.list_tools_request(2), "tools/list"}
          ] do
        assert request == %{
                 "jsonrpc" => "2.0",
                 "id" => request["id"],
                 "method" => method,
                 "params" => %{"_meta" => MCP.request_meta()}
               }

        assert get_in(request, ["params", "_meta", "io.modelcontextprotocol/protocolVersion"]) ==
                 "2026-07-28"

        assert get_in(request, [
                 "params",
                 "_meta",
                 "io.modelcontextprotocol/clientCapabilities",
                 "extensions",
                 "ai.frontman/execution-context",
                 "version"
               ]) == 1
      end
    end

    test "builds tools/call without legacy wire identity" do
      request =
        MCP.build_tool_execution(%MCP.ToolCallParams{
          request_id: "request-1",
          task_id: "task-1",
          tool_name: "search_files",
          arguments: %{"query" => "secret"},
          tool_call_id: "tool-call-1"
        })

      assert request["id"] == "request-1"
      assert request["method"] == "tools/call"
      assert request["params"]["name"] == "search_files"
      assert request["params"]["arguments"] == %{"query" => "secret"}
      assert Map.keys(request["params"]) |> Enum.sort() == ["_meta", "arguments", "name"]

      assert request["params"]["_meta"]["ai.frontman/execution-context"] == %{
               "taskId" => "task-1",
               "toolCallId" => "tool-call-1"
             }
    end

    @tag capture_log: true
    test "never logs argument values" do
      log =
        capture_log([level: :info], fn ->
          MCP.build_tool_execution(%MCP.ToolCallParams{
            request_id: 1,
            task_id: "task-1",
            tool_name: "read_file",
            arguments: %{"path" => "private-argument-marker"},
            tool_call_id: "tool-call-1"
          })
        end)

      refute log =~ "private-argument-marker"
      refute log =~ "path"
    end

    test "rejects integers outside the JSON safe range" do
      assert_raise ArgumentError, fn -> MCP.discover_request(9_007_199_254_740_992) end
    end
  end

  describe "discovery compatibility" do
    test "requires the protocol version and execution-context extension" do
      result = discover_result()
      assert :ok = MCP.validate_discovery_compatibility(result)

      assert {:error, "unsupported_protocol_version"} =
               MCP.validate_discovery_compatibility(%{
                 result
                 | "supportedVersions" => ["2025-11-25"]
               })

      assert {:error, "missing_required_server_extension"} =
               MCP.validate_discovery_compatibility(%{
                 result
                 | "capabilities" => %{"tools" => %{}}
               })
    end
  end

  describe "response parsing" do
    test "validates discovery, list, and complete call results by method" do
      assert {:ok, {:success, 1, _result}} =
               MCP.parse_response(
                 JsonRpc.success_response(1, discover_result()),
                 "server/discover"
               )

      list_result = %{
        "resultType" => "tools",
        "tools" => [
          %{
            "name" => "read_file",
            "inputSchema" => %{"type" => "object"},
            "annotations" => %{"readOnlyHint" => true}
          }
        ],
        "ttlMs" => 0,
        "cacheScope" => "private"
      }

      assert {:ok, {:success, "list-1", ^list_result}} =
               MCP.parse_response(
                 JsonRpc.success_response("list-1", list_result),
                 "tools/list"
               )

      call_result = %{
        "resultType" => "complete",
        "content" => [%{"type" => "text", "text" => "ok"}],
        "structuredContent" => false,
        "_meta" => %{"vendor.example/open" => %{"value" => 1}},
        "openField" => [1, 2]
      }

      assert {:ok, {:success, 3, ^call_result}} =
               MCP.parse_response(JsonRpc.success_response(3, call_result), "tools/call")
    end

    test "rejects unsafe IDs, mixed envelopes, incomplete results, and malformed content" do
      assert {:error, :invalid_id} =
               MCP.parse_response(%{
                 "jsonrpc" => "2.0",
                 "id" => 9_007_199_254_740_992,
                 "result" => %{}
               })

      assert {:error, :invalid_message} =
               MCP.parse_response(%{
                 "jsonrpc" => "2.0",
                 "id" => 1,
                 "result" => %{},
                 "error" => %{"code" => -32_600, "message" => "bad"}
               })

      for result <- [
            %{"content" => []},
            %{"resultType" => "input_required", "content" => []},
            %{"resultType" => "complete", "content" => [%{"type" => "text"}]},
            %{"resultType" => "complete", "content" => [], "isError" => "false"}
          ] do
        assert {:error, :invalid_call_tool_result} =
                 MCP.parse_response(JsonRpc.success_response(1, result), "tools/call")
      end
    end

    test "checks modern named error payloads" do
      missing_capability = %{
        "code" => -32_021,
        "message" => "Missing capability",
        "data" => %{"requiredCapabilities" => MCP.client_capabilities()}
      }

      assert MCP.missing_required_client_capability_error?(missing_capability)
      refute MCP.header_mismatch_error?(missing_capability)

      response = %{"jsonrpc" => "2.0", "id" => 1, "error" => missing_capability}
      assert {:ok, {:error, 1, ^missing_capability}} = MCP.parse_response(response)

      parse_error = %{"code" => -32_700, "message" => "Parse error"}

      assert {:ok, {:error, nil, ^parse_error}} =
               MCP.parse_response(%{"jsonrpc" => "2.0", "id" => nil, "error" => parse_error})

      assert {:error, :invalid_error} =
               MCP.parse_response(%{
                 "jsonrpc" => "2.0",
                 "id" => 1,
                 "error" => %{"code" => -32_022, "message" => "Unsupported"}
               })
    end
  end

  describe "result constructors" do
    test "always builds complete results and preserves primitive structured JSON" do
      for result <- [
            MCP.tool_result_text("ok"),
            MCP.tool_result_json(7),
            MCP.tool_result_json(false),
            MCP.tool_result_json(nil),
            MCP.tool_result_image("aW1hZ2U=", "image/png"),
            MCP.tool_result_error("failed")
          ] do
        assert result["resultType"] == "complete"
        assert is_list(result["content"])
      end

      assert MCP.tool_result_json(7)["structuredContent"] == 7
      assert MCP.tool_result_json(false)["structuredContent"] == false
      assert Map.has_key?(MCP.tool_result_json(nil), "structuredContent")
    end
  end

  defp discover_result do
    %{
      "resultType" => "discovery",
      "supportedVersions" => [MCP.protocol_version()],
      "capabilities" => %{
        "tools" => %{},
        "extensions" => %{"ai.frontman/execution-context" => %{"version" => 1}}
      },
      "ttlMs" => 0,
      "cacheScope" => "private"
    }
  end
end
