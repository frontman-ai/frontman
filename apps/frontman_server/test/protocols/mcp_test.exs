defmodule FrontmanServer.Protocols.MCPTest do
  use ExUnit.Case, async: true

  import FrontmanServer.Test.Fixtures.Tools, only: [mcp_tool: 2]

  alias FrontmanServer.Protocols.MCP
  alias FrontmanServer.Protocols.MCP.Schema
  alias FrontmanServerWeb.ChannelCase

  test "declines valid MRTR interims without applying final output constraints or retaining state" do
    output_schema = %{"type" => "object", "required" => ["final"]}

    for fields <- [
          %{"requestState" => "opaque-private-state"},
          %{"inputRequests" => %{}},
          %{"inputRequests" => %{}, "requestState" => ""}
        ] do
      result = Map.put(fields, "resultType", "input_required")
      assert {:ok, declined} = Schema.resolve_call_tool_result(result, output_schema)
      assert declined["isError"] == true
      assert MCP.extract_content_text(declined) =~ "declines MRTR retry"
      refute Jason.encode!(declined) =~ "opaque-private-state"
      refute Map.has_key?(declined, "requestState")
      refute Map.has_key?(declined, "inputRequests")
    end
  end

  test "rejects malformed MRTR envelopes and unnegotiated input requests" do
    capabilities = MCP.request_params()["_meta"]["io.modelcontextprotocol/clientCapabilities"]
    refute Map.has_key?(capabilities, "roots")
    refute Map.has_key?(capabilities, "sampling")
    refute Map.has_key?(capabilities, "elicitation")

    for fields <- [
          %{},
          %{"requestState" => nil},
          %{"requestState" => %{}},
          %{"inputRequests" => []},
          %{"inputRequests" => nil, "requestState" => "opaque"},
          %{"inputRequests" => %{}, "_meta" => []},
          %{"inputRequests" => %{"invalid" => false}},
          %{
            "inputRequests" => %{
              "roots" => %{"method" => "roots/list"},
              "sampling" => %{
                "method" => "sampling/createMessage",
                "params" => %{"messages" => [], "maxTokens" => 100}
              }
            },
            "requestState" => "opaque"
          }
        ] do
      assert :error =
               fields
               |> Map.put("resultType", "input_required")
               |> Schema.resolve_call_tool_result()
    end
  end

  test "normal complete results retain final validation and are returned unchanged" do
    result = Map.put(MCP.tool_result_text("done"), "structuredContent", %{"final" => true})
    schema = %{"type" => "object", "required" => ["final"]}
    assert {:ok, ^result} = Schema.resolve_call_tool_result(result, schema)

    assert :error =
             Schema.resolve_call_tool_result(Map.delete(result, "structuredContent"), schema)

    error = MCP.tool_result_error("failed")
    assert {:ok, ^error} = Schema.resolve_call_tool_result(error, schema)
    assert :error = Schema.resolve_call_tool_result(%{"resultType" => "unknown"})
  end

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
end
