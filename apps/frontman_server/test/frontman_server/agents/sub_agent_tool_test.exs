defmodule FrontmanServer.Agents.SubAgentToolTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents.SubAgentTool

  describe "tool_name/0" do
    test "returns spawn_sub_agent" do
      assert SubAgentTool.tool_name() == "spawn_sub_agent"
    end
  end

  describe "tool_definition/0" do
    test "returns valid tool definition" do
      definition = SubAgentTool.tool_definition()

      assert definition.name == "spawn_sub_agent"
      assert is_binary(definition.description)
      assert definition.parameters.type == "object"
      assert "agent" in definition.parameters.required
      assert "message" in definition.parameters.required
    end

    test "includes all valid agent types in enum" do
      definition = SubAgentTool.tool_definition()
      enum = definition.parameters.properties.agent.enum

      assert "research" in enum
      assert "planning" in enum
      assert "validator" in enum
      assert length(enum) == 3
    end

    test "description mentions available agent types" do
      definition = SubAgentTool.tool_definition()

      assert definition.description =~ "research"
      assert definition.description =~ "planning"
      assert definition.description =~ "validator"
    end
  end

  describe "parse_arguments/1" do
    test "parses valid research agent arguments" do
      args = %{"agent" => "research", "message" => "Find information about X"}
      assert {:ok, parsed} = SubAgentTool.parse_arguments(args)
      assert parsed.role == :research
      assert parsed.message == "Find information about X"
    end

    test "parses valid planning agent arguments" do
      args = %{"agent" => "planning", "message" => "Create a plan for Y"}
      assert {:ok, parsed} = SubAgentTool.parse_arguments(args)
      assert parsed.role == :planning
      assert parsed.message == "Create a plan for Y"
    end

    test "parses valid validator agent arguments" do
      args = %{"agent" => "validator", "message" => "Validate the implementation"}
      assert {:ok, parsed} = SubAgentTool.parse_arguments(args)
      assert parsed.role == :validator
      assert parsed.message == "Validate the implementation"
    end

    test "returns error for invalid agent type" do
      args = %{"agent" => "invalid_type", "message" => "Do something"}
      assert {:error, msg} = SubAgentTool.parse_arguments(args)
      assert msg =~ "Invalid agent type"
      assert msg =~ "research"
      assert msg =~ "planning"
      assert msg =~ "validator"
    end

    test "returns error for empty message" do
      args = %{"agent" => "research", "message" => "   "}
      assert {:error, msg} = SubAgentTool.parse_arguments(args)
      assert msg =~ "empty"
    end

    test "returns error for missing agent parameter" do
      args = %{"message" => "Do something"}
      assert {:error, msg} = SubAgentTool.parse_arguments(args)
      assert msg =~ "agent"
    end

    test "returns error for missing message parameter" do
      args = %{"agent" => "research"}
      assert {:error, msg} = SubAgentTool.parse_arguments(args)
      assert msg =~ "message"
    end

    test "returns error for empty arguments" do
      assert {:error, msg} = SubAgentTool.parse_arguments(%{})
      assert msg =~ "Missing required parameters"
    end
  end
end
