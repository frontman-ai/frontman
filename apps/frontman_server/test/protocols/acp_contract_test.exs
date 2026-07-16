defmodule FrontmanServer.Protocols.AcpContractTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.ProtocolSchema

  describe "AgentClientProtocol.build_initialize_result/0" do
    test "validates against acp/initializeResult schema" do
      payload = AgentClientProtocol.build_initialize_result()
      ProtocolSchema.validate!(payload, "acp/initializeResult")
    end

    test "advertises Frontman agent attribution v1 under capability metadata" do
      assert %{
               "agentCapabilities" => %{
                 "_meta" => %{
                   "frontman.dev" => %{"agentAttribution" => %{"version" => 1}}
                 }
               }
             } = AgentClientProtocol.build_initialize_result()
    end
  end

  describe "AgentClientProtocol.negotiate_agent_attribution_version/1" do
    test "negotiates v1 from a matching client advertisement" do
      capabilities = %{
        "_meta" => %{
          "frontman.dev" => %{"agentAttribution" => %{"version" => 1}}
        }
      }

      assert {:ok, 1} =
               AgentClientProtocol.negotiate_agent_attribution_version(capabilities)
    end

    test "disables attribution when advertisement is absent or unsupported" do
      assert {:ok, nil} = AgentClientProtocol.negotiate_agent_attribution_version(nil)
      assert {:ok, nil} = AgentClientProtocol.negotiate_agent_attribution_version(%{})

      assert {:ok, nil} =
               AgentClientProtocol.negotiate_agent_attribution_version(%{
                 "_meta" => %{
                   "frontman.dev" => %{"agentAttribution" => %{"version" => 2}}
                 }
               })
    end

    test "rejects malformed known metadata" do
      assert {:error, _message} =
               AgentClientProtocol.negotiate_agent_attribution_version(%{
                 "_meta" => %{"frontman.dev" => "invalid"}
               })

      assert {:error, _message} =
               AgentClientProtocol.negotiate_agent_attribution_version(%{
                 "_meta" => %{
                   "frontman.dev" => %{"agentAttribution" => %{"version" => 0}}
                 }
               })
    end
  end

  describe "AgentClientProtocol.build_prompt_accepted_result/0" do
    test "validates against acp/promptResult schema" do
      payload = AgentClientProtocol.build_prompt_accepted_result()

      ProtocolSchema.validate!(payload, "acp/promptResult")
    end
  end

  test "session results use identical agent catalog metadata" do
    catalog = [
      %{
        "id" => "executor",
        "name" => "executor",
        "displayName" => "Executor",
        "description" => "Executes work",
        "color" => "#985DF7"
      }
    ]

    new_result = AgentClientProtocol.build_session_new_result("session-123", [], catalog)
    load_result = AgentClientProtocol.build_session_load_result([], catalog)

    assert new_result["_meta"] == load_result["_meta"]
    assert new_result["_meta"]["frontman.dev/agents"] == catalog
  end

  test "user message notification includes complete attribution metadata" do
    content = %{"type" => "text", "text" => "Hello"}

    notification =
      AgentClientProtocol.build_user_message_chunk_notification(
        "session-123",
        "message-123",
        content,
        "executor",
        ~U[2026-07-14 12:30:00.123456Z]
      )

    assert get_in(notification, ["params", "update"]) == %{
             "sessionUpdate" => "user_message_chunk",
             "messageId" => "message-123",
             "content" => content,
             "_meta" => %{
               "frontman.dev/agentId" => "executor",
               "frontman.dev/timestamp" => "2026-07-14T12:30:00.123456Z"
             }
           }
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

  describe "AgentClientProtocol.build_error_notification/4" do
    test "validates against jsonrpc/notification and acp/sessionUpdateNotification schemas" do
      payload =
        AgentClientProtocol.build_error_notification(
          "session-123",
          "Rate limit exceeded",
          DateTime.utc_now(),
          category: "rate_limit",
          agent_error_id: "agent-error-123"
        )

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")

      assert %{
               "params" => %{
                 "update" => %{"_meta" => %{"frontman.dev/agentErrorId" => "agent-error-123"}}
               }
             } = payload
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
