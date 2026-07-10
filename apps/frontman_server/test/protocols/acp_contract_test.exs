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

  describe "AgentClientProtocol.build_prompt_accepted_result/0" do
    test "validates against acp/promptResult schema" do
      payload = AgentClientProtocol.build_prompt_accepted_result()

      ProtocolSchema.validate!(payload, "acp/promptResult")
    end
  end

  describe "AgentClientProtocol.build_agent_message_chunk_notification/3" do
    test "validates against jsonrpc/notification and acp/sessionUpdateNotification schemas" do
      payload =
        AgentClientProtocol.build_agent_message_chunk_notification(
          "session-123",
          "Hello world",
          DateTime.utc_now()
        )

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")
    end
  end

  describe "AgentClientProtocol.build_user_message_notification/3" do
    test "validates against jsonrpc/notification and acp/sessionUpdateNotification schemas" do
      payload =
        AgentClientProtocol.build_user_message_notification(
          "session-123",
          "msg-123",
          [%{"type" => "text", "text" => "Hello from user"}]
        )

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")

      assert %{
               "params" => %{
                 "update" => %{
                   "sessionUpdate" => "user_message",
                   "messageId" => "msg-123",
                   "content" => [%{"type" => "text", "text" => "Hello from user"}]
                 }
               }
             } = payload
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
          DateTime.utc_now(),
          "pending"
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

  describe "AgentClientProtocol.build_error_notification/6" do
    test "validates against jsonrpc/notification and acp/sessionUpdateNotification schemas" do
      payload =
        AgentClientProtocol.build_error_notification(
          "session-123",
          "Rate limit exceeded",
          DateTime.utc_now(),
          "rate_limit",
          "agent-error-123"
        )

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")

      assert %{
               "params" => %{
                 "update" => %{"_meta" => %{"frontman.dev/agentErrorId" => "agent-error-123"}}
               }
             } = payload
    end

    test "keeps manual retry availability separate from automatic retry fields" do
      manual_payload =
        AgentClientProtocol.build_error_notification(
          "session-123",
          "Quota reached",
          ~U[2030-10-21 06:28:00Z],
          "quota",
          "agent-error-123",
          retry_available_at: ~U[2030-10-21 07:28:00Z]
        )

      ProtocolSchema.validate!(manual_payload, "jsonrpc/notification")
      ProtocolSchema.validate!(manual_payload, "acp/sessionUpdateNotification")

      assert %{
               "params" => %{
                 "update" => %{
                   "sessionUpdate" => "error",
                   "category" => "quota",
                   "retryAvailableAt" => "2030-10-21T07:28:00Z"
                 }
               }
             } = manual_payload

      auto_payload =
        AgentClientProtocol.build_error_notification(
          "session-123",
          "Rate limited",
          ~U[2030-10-21 06:28:00Z],
          "rate_limit",
          "agent-error-123",
          retry_at: ~U[2030-10-21 06:28:10Z],
          attempt: 1,
          max_attempts: 5
        )

      update = auto_payload["params"]["update"]

      refute Map.has_key?(manual_payload["params"]["update"], "retryAt")
      assert update["retryAt"] == "2030-10-21T06:28:10Z"
      assert update["attempt"] == 1
      assert update["maxAttempts"] == 5
      refute Map.has_key?(update, "retryAvailableAt")
    end
  end

  describe "AgentClientProtocol.build_state_update_notification/3" do
    test "validates running state against jsonrpc/notification and acp/sessionUpdateNotification schemas" do
      payload = AgentClientProtocol.build_state_update_notification("session-123", "running")

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")

      assert %{
               "params" => %{
                 "update" => %{
                   "sessionUpdate" => "state_update",
                   "state" => "running"
                 }
               }
             } = payload
    end

    test "validates idle state with stop reason" do
      payload =
        AgentClientProtocol.build_state_update_notification(
          "session-123",
          "idle",
          AgentClientProtocol.stop_reason_end_turn()
        )

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")

      assert %{
               "params" => %{
                 "update" => %{
                   "sessionUpdate" => "state_update",
                   "state" => "idle",
                   "stopReason" => "end_turn"
                 }
               }
             } = payload
    end

    test "validates requires_action state" do
      payload =
        AgentClientProtocol.build_state_update_notification("session-123", "requires_action")

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
