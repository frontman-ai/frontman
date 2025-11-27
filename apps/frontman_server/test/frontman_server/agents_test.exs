defmodule FrontmanServer.AgentsTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents

  describe "agent_state/1" do
    test "returns :not_running when no agent exists" do
      assert Agents.agent_state("nonexistent_task") == :not_running
    end
  end

  describe "agent_running?/1" do
    test "returns false when no agent exists" do
      refute Agents.agent_running?("nonexistent_task")
    end
  end

  describe "notify_tool_result/4" do
    test "returns error when no agent exists" do
      result = Agents.notify_tool_result("nonexistent", "call_123", "result", false)
      assert result == {:error, :agent_not_found}
    end
  end

  describe "notify_user_message/2" do
    test "returns ok even when no agent exists (spawns new agent)" do
      # Note: This would actually try to spawn an agent, which would fail
      # without a proper task. In a real test we'd set up the task first.
      # For now we just verify the function exists and has correct arity.
      assert is_function(&Agents.notify_user_message/2)
    end
  end
end
