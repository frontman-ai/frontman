defmodule AgentClientProtocolTest do
  use ExUnit.Case, async: true

  alias AgentClientProtocol, as: ACP

  describe "plan_update/2" do
    test "builds valid plan update notification" do
      entries = [
        %{"content" => "Test task", "priority" => "medium", "status" => "pending"}
      ]

      result = ACP.plan_update("sess_123", entries)

      assert result["jsonrpc"] == "2.0"
      assert result["method"] == "session/update"
      assert result["params"]["sessionId"] == "sess_123"
      assert result["params"]["update"]["sessionUpdate"] == "plan"
      assert result["params"]["update"]["entries"] == entries
    end

    test "validates entries have required fields" do
      invalid_entries = [%{"content" => "Missing priority and status"}]

      assert_raise ArgumentError, fn ->
        ACP.plan_update("sess_123", invalid_entries)
      end
    end

    test "validates priority values" do
      invalid_entries = [
        %{"content" => "Test", "priority" => "urgent", "status" => "pending"}
      ]

      assert_raise ArgumentError, fn ->
        ACP.plan_update("sess_123", invalid_entries)
      end
    end

    test "validates status values" do
      invalid_entries = [
        %{"content" => "Test", "priority" => "medium", "status" => "done"}
      ]

      assert_raise ArgumentError, fn ->
        ACP.plan_update("sess_123", invalid_entries)
      end
    end

    test "accepts valid entries with all status values" do
      entries = [
        %{"content" => "Pending", "priority" => "medium", "status" => "pending"},
        %{"content" => "In progress", "priority" => "high", "status" => "in_progress"},
        %{"content" => "Done", "priority" => "low", "status" => "completed"}
      ]

      notification = ACP.plan_update("sess_test", entries)
      assert notification["params"]["update"]["entries"] == entries
    end

    test "accepts empty entries list" do
      notification = ACP.plan_update("sess_test", [])
      assert notification["params"]["update"]["entries"] == []
    end
  end
end
