defmodule FrontmanServer.Protocols.MCPTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import FrontmanServer.Test.Fixtures.Tools, only: [mcp_tool: 2]

  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Protocols.MCP.Schema
  alias FrontmanServerWeb.ChannelCase

  test "implicit and explicit 2020-12 compile local refs and enforce output constraints" do
    for dialect <- [%{}, %{"$schema" => "https://json-schema.org/draft/2020-12/schema"}] do
      schema =
        Map.merge(dialect, %{
          "type" => "object",
          "$defs" => %{"name" => %{"type" => "string", "minLength" => 1}},
          "properties" => %{"name" => %{"$ref" => "#/$defs/name"}},
          "required" => ["name"],
          "unevaluatedProperties" => false
        })

      tool = mcp_tool("local_refs", %{"inputSchema" => schema, "outputSchema" => schema})
      assert :ok = Schema.validate_tools_list_result(ChannelCase.mcp_tools_result([tool]))

      result = Map.put(MCP.tool_result_text("name"), "structuredContent", %{"name" => "Ada"})
      assert :ok = Schema.validate_call_tool_result(result, schema)

      for invalid <- [%{"name" => ""}, %{"name" => 1}, %{}, %{"name" => "Ada", "extra" => 1}] do
        assert :error =
                 Schema.validate_call_tool_result(
                   Map.put(result, "structuredContent", invalid),
                   schema
                 )
      end
    end
  end

  test "schema container depth allows 64 edges and scalar leaves at 65, but not containers" do
    for wrap <- [&%{"child" => &1}, &[&1]], depth <- [64, 65] do
      nested = Enum.reduce(1..depth, true, fn _edge, child -> wrap.(child) end)
      schema = %{"type" => "object", "default" => nested}

      expected =
        case depth do
          64 -> :ok
          65 -> :error
        end

      for field <- ["inputSchema", "outputSchema"] do
        tool = mcp_tool("depth", %{field => schema})
        assert expected == Schema.validate_tools_list_result(ChannelCase.mcp_tools_result([tool]))
      end

      result = Map.put(MCP.tool_result_text("depth"), "structuredContent", %{})
      assert expected == Schema.validate_call_tool_result(result, schema)
    end
  end

  test "schema node budget counts containers and scalars across siblings, separately per schema" do
    for {count, expected} <- [{9_997, :ok}, {9_998, :error}],
        default <- [
          List.duplicate(nil, count),
          %{"left" => List.duplicate(nil, 5_000), "right" => List.duplicate(nil, count - 5_002)}
        ] do
      schema = %{"type" => "object", "default" => default}

      for field <- ["inputSchema", "outputSchema"] do
        tool = mcp_tool("nodes", %{field => schema})
        assert expected == Schema.validate_tools_list_result(ChannelCase.mcp_tools_result([tool]))
      end

      result = Map.put(MCP.tool_result_text("nodes"), "structuredContent", %{})
      assert expected == Schema.validate_call_tool_result(result, schema)
    end

    schema = %{"type" => "object", "default" => List.duplicate(nil, 9_997)}
    tool = mcp_tool("separate", %{"inputSchema" => schema, "outputSchema" => schema})
    assert :ok = Schema.validate_tools_list_result(ChannelCase.mcp_tools_result([tool]))
  end

  test "ordinary composition and productive local recursion remain accepted" do
    schema = %{
      "type" => "object",
      "allOf" => [%{"properties" => %{"child" => %{"$ref" => "#"}}}]
    }

    tool = mcp_tool("recursive", %{"inputSchema" => schema, "outputSchema" => schema})
    assert :ok = Schema.validate_tools_list_result(ChannelCase.mcp_tools_result([tool]))

    result = Map.put(MCP.tool_result_text("recursive"), "structuredContent", %{"child" => %{}})
    assert :ok = Schema.validate_call_tool_result(result, schema)
  end

  test "metaschemas reject malformed keywords across all runtime compilation paths" do
    for dialect <- [
          nil,
          "https://json-schema.org/draft/2020-12/schema",
          "http://json-schema.org/draft-07/schema#"
        ],
        invalid <- [
          %{"minLength" => -1},
          %{"minItems" => -1},
          %{"properties" => %{"nested" => %{"minLength" => -1}}},
          %{"required" => "x"},
          %{"required" => [1]},
          %{"required" => ["x", "x"]},
          %{"enum" => "x"},
          %{"$schema" => nil}
        ] do
      schema =
        case dialect do
          nil -> %{"type" => "object"}
          uri -> %{"type" => "object", "$schema" => uri}
        end

      schema = Map.merge(schema, invalid)

      for field <- ["inputSchema", "outputSchema"] do
        tool = mcp_tool("invalid", %{field => schema})
        assert :error = Schema.validate_tools_list_result(ChannelCase.mcp_tools_result([tool]))
      end

      result = Map.put(MCP.tool_result_text("invalid"), "structuredContent", %{})
      assert :error = Schema.validate_call_tool_result(result, schema)
    end
  end

  test "supported dialect aliases preserve dialect keywords, extensions and untyped outputs" do
    for {dialect, keywords} <- [
          {"https://json-schema.org/draft/2020-12/schema",
           %{"prefixItems" => [%{"type" => "string"}]}},
          {"http://json-schema.org/draft-07/schema", %{"items" => [%{"type" => "string"}]}}
        ],
        suffix <- ["", "#"] do
      output = Map.merge(keywords, %{"$schema" => dialect <> suffix, "x-extension" => true})
      input = Map.put(output, "type", "object")
      tool = mcp_tool("dialect", %{"inputSchema" => input, "outputSchema" => output})
      assert :ok = Schema.validate_tools_list_result(ChannelCase.mcp_tools_result([tool]))
      result = Map.put(MCP.tool_result_text("dialect"), "structuredContent", ["valid"])
      assert :ok = Schema.validate_call_tool_result(result, output)

      assert :error =
               Schema.validate_call_tool_result(Map.put(result, "structuredContent", [1]), output)

      tool = Map.put(tool, "inputSchema", output)
      assert :error = Schema.validate_tools_list_result(ChannelCase.mcp_tools_result([tool]))
    end
  end

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
