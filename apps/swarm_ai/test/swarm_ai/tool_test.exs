defmodule SwarmAi.ToolTest do
  use ExUnit.Case, async: true

  alias SwarmAi.Tool

  describe "new/1" do
    test "creates a tool with all required fields" do
      tool =
        Tool.new(
          name: "my_tool",
          description: "Does something",
          parameter_schema: %{},
          timeout_ms: 30_000,
          on_timeout: :error
        )

      assert tool.name == "my_tool"
      assert tool.description == "Does something"
      assert tool.parameter_schema == %{}
      assert tool.timeout_ms == 30_000
      assert tool.on_timeout == :error
    end

    test "raises on missing timeout_ms" do
      assert_raise ArgumentError, fn ->
        Tool.new(
          name: "t",
          description: "d",
          parameter_schema: %{},
          on_timeout: :error
        )
      end
    end

    test "raises on missing on_timeout" do
      assert_raise ArgumentError, fn ->
        Tool.new(
          name: "t",
          description: "d",
          parameter_schema: %{},
          timeout_ms: 5_000
        )
      end
    end

    test "raises on unknown key" do
      assert_raise KeyError, fn ->
        Tool.new(
          name: "t",
          description: "d",
          parameter_schema: %{},
          timeout_ms: 5_000,
          on_timeout: :error,
          extra: "nope"
        )
      end
    end
  end
end
