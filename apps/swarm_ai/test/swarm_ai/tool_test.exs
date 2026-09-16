defmodule SwarmAi.ToolTest do
  use ExUnit.Case, async: true

  alias SwarmAi.Tool

  describe "new/1" do
    test "creates a model-facing declaration without operational fields" do
      tool =
        Tool.new(
          name: "my_tool",
          description: "Does something",
          access: :read,
          parameter_schema: %{}
        )

      assert tool.name == "my_tool"
      assert tool.description == "Does something"
      assert tool.access == :read
      assert tool.parameter_schema == %{}
      refute Map.has_key?(tool, :timeout_ms)
      refute Map.has_key?(tool, :on_timeout)
    end

    test "raises on missing required declaration fields" do
      assert_raise ArgumentError, fn ->
        Tool.new(name: "t", description: "d", access: :read)
      end
    end

    test "rejects operational timeout fields and unknown keys" do
      for key <- [:timeout_ms, :on_timeout, :extra] do
        assert_raise KeyError, fn ->
          Tool.new(
            [name: "t", description: "d", access: :read, parameter_schema: %{}] ++ [{key, 5_000}]
          )
        end
      end
    end
  end
end
