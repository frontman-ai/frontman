defmodule SwarmAi.ToolCallTest do
  use ExUnit.Case, async: true

  test "arguments can be parsed as JSON" do
    tool_call = %SwarmAi.ToolCall{
      id: "tc_1",
      name: "get_weather",
      arguments: ~s({"city":"NYC","units":"celsius"})
    }

    assert {:ok, args} = SwarmAi.ToolCall.parse_arguments(tool_call)
    assert args["city"] == "NYC"
    assert args["units"] == "celsius"
  end

  test "invalid JSON returns error" do
    tool_call = %SwarmAi.ToolCall{id: "tc_1", name: "test", arguments: "not json"}
    assert {:error, reason} = SwarmAi.ToolCall.parse_arguments(tool_call)
    assert reason =~ "unexpected byte"
  end

  test "blank and non-object JSON arguments are handled" do
    tool_call = %SwarmAi.ToolCall{id: "tc_1", name: "test", arguments: "  \n  "}
    assert {:ok, %{}} = SwarmAi.ToolCall.parse_arguments(tool_call)

    tool_call = %SwarmAi.ToolCall{id: "tc_1", name: "test", arguments: ~s(["not", "object"])}
    assert {:error, reason} = SwarmAi.ToolCall.parse_arguments(tool_call)
    assert reason =~ "expected JSON object"
  end
end
