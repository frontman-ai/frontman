defmodule FrontmanServer.Protocols.AcpContractTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.ProtocolSchema

  describe "AgentClientProtocol.build_initialize_result/0" do
    test "validates against acp/initializeResult schema" do
      payload = AgentClientProtocol.build_initialize_result()
      ProtocolSchema.validate!(payload, "acp/initializeResult")
    end
  end

  describe "AgentClientProtocol.build_session_new_result/1" do
    test "validates against acp/sessionNewResult schema" do
      payload = AgentClientProtocol.build_session_new_result("session-123")
      ProtocolSchema.validate!(payload, "acp/sessionNewResult")
    end
  end

  describe "AgentClientProtocol.build_prompt_result/1" do
    test "validates against acp/promptResult schema" do
      payload =
        AgentClientProtocol.build_prompt_result(AgentClientProtocol.stop_reason_end_turn())

      ProtocolSchema.validate!(payload, "acp/promptResult")
    end
  end

  describe "AgentClientProtocol.build_agent_message_chunk_notification/2" do
    test "validates against jsonrpc/notification and acp/sessionUpdateNotification schemas" do
      payload =
        AgentClientProtocol.build_agent_message_chunk_notification("session-123", "Hello world")

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")
    end
  end

  describe "AgentClientProtocol.tool_call_create/6" do
    test "validates against jsonrpc/notification and acp/sessionUpdateNotification schemas" do
      payload =
        AgentClientProtocol.tool_call_create(
          "session-123",
          "tc-1",
          "read_file",
          "other",
          "pending"
        )

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")
    end

    test "with sub-agent fields validates against acp/sessionUpdateNotification schema" do
      payload =
        AgentClientProtocol.tool_call_create(
          "session-123",
          "tc-1",
          "read_file",
          "other",
          "pending",
          parent_agent_id: "agent-1",
          spawning_tool_name: "dispatch"
        )

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")
    end
  end

  describe "AgentClientProtocol.tool_call_update/4" do
    test "without content validates against acp/sessionUpdateNotification schema" do
      payload =
        AgentClientProtocol.tool_call_update("session-123", "tc-1", "completed")

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")
    end

    test "with content validates against acp/sessionUpdateNotification schema" do
      content = [%{"type" => "content", "content" => %{"type" => "text", "text" => "result"}}]

      payload =
        AgentClientProtocol.tool_call_update("session-123", "tc-1", "completed", content)

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")
    end
  end

  describe "AgentClientProtocol.plan_update/2" do
    test "validates against acp/sessionUpdateNotification schema" do
      entries = [
        %{
          "content" => "Analyze the codebase",
          "priority" => "high",
          "status" => "in_progress"
        },
        %{
          "content" => "Implement solution",
          "priority" => "medium",
          "status" => "pending"
        }
      ]

      payload = AgentClientProtocol.plan_update("session-123", entries)
      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")
    end
  end

  describe "AgentClientProtocol.agent_info/0" do
    test "validates against acp/implementation schema" do
      payload = AgentClientProtocol.agent_info()
      ProtocolSchema.validate!(payload, "acp/implementation")
    end
  end
end
