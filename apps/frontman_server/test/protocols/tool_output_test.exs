defmodule FrontmanServer.Protocols.MCP.ToolOutputTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Protocols.MCP.ToolOutput

  test "validates arbitrary structured JSON and preserves presence and errors" do
    for {type, value} <- [
          {"object", %{"a" => 1}},
          {"array", [1]},
          {"string", "hello"},
          {"number", 1.5},
          {"boolean", false},
          {"null", nil}
        ] do
      result = %{"resultType" => "complete", "content" => [], "structuredContent" => value}
      assert {:ok, output} = ToolOutput.new(result, %{"type" => type})
      assert output.structured_content === {:present, value}
      assert output.content == []
      refute output.is_error
      assert :error = ToolOutput.new(result, %{"not" => %{"type" => type}})
    end

    assert {:ok, absent} = ToolOutput.new(%{"content" => []})
    assert absent.structured_content == :absent
    assert :error = ToolOutput.new(%{"content" => []}, %{"type" => "null"})
    assert {:ok, error} = ToolOutput.new(%{"content" => [], "isError" => true})
    assert error.is_error
    assert :error = ToolOutput.new(%{"content" => "invalid"})
    assert :error = ToolOutput.new(%{"resultType" => "input_required", "requestState" => ""})
  end

  test "only parsed JSON equivalence suppresses the additional structured block" do
    for value <- [%{"a" => 1}, [1], "hello", 2.5, false, nil] do
      json = Jason.encode!(value)
      block = %{"type" => "text", "text" => " \n" <> json}
      result = %{"content" => [block], "structuredContent" => value, "isError" => true}
      assert {:ok, output} = ToolOutput.new(result)
      assert ToolOutput.content_blocks(output) == [block]
      assert output.is_error
    end

    result = %{
      "content" => [%{"type" => "text", "text" => "hello"}],
      "structuredContent" => "hello"
    }

    assert {:ok, output} = ToolOutput.new(result)

    assert ToolOutput.content_blocks(output) ==
             result["content"] ++ [%{"type" => "text", "text" => ~s("hello")}]
  end
end
