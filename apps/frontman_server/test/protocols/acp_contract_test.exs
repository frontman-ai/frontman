defmodule FrontmanServer.Protocols.AcpContractTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents.Agent
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

  describe "AgentClientProtocol session agent catalog" do
    test "encodes resolved agents into identical session metadata" do
      catalog =
        [agent("executor", "Executor"), agent("planner", "Planner")]
        |> AgentClientProtocol.build_agent_catalog()

      new_result = AgentClientProtocol.build_session_new_result("session-123", [], catalog)
      load_result = AgentClientProtocol.build_session_load_result([], catalog)

      assert new_result["_meta"] == load_result["_meta"]
      assert new_result["_meta"]["frontman.dev/agents"] == catalog
      ProtocolSchema.validate!(new_result, "acp/sessionNewResult")
      ProtocolSchema.validate!(load_result, "acp/sessionLoadResult")
    end
  end

  defp agent(id, display_name) do
    %Agent{
      id: id,
      name: String.downcase(display_name),
      display_name: display_name,
      description: "#{display_name} description",
      color: "#985DF7",
      system: "System"
    }
  end

  describe "AgentClientProtocol.build_prompt_accepted_result/0" do
    test "validates against acp/promptResult schema" do
      payload = AgentClientProtocol.build_prompt_accepted_result()

      ProtocolSchema.validate!(payload, "acp/promptResult")
    end
  end

  describe "AgentClientProtocol.build_agent_message_chunk_notification/5" do
    test "validates against jsonrpc/notification and acp/sessionUpdateNotification schemas" do
      timestamp = ~U[2026-07-14 12:30:01.000000Z]

      payload =
        AgentClientProtocol.build_agent_message_chunk_notification(
          "session-123",
          "Hello world",
          timestamp,
          AgentClientProtocol.agent_message_id("turn-123", 2),
          "executor-id"
        )

      ProtocolSchema.validate!(payload, "jsonrpc/notification")
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")

      assert %{
               "params" => %{
                 "update" => %{
                   "sessionUpdate" => "agent_message_chunk",
                   "messageId" => "turn-123:2",
                   "content" => %{"type" => "text", "text" => "Hello world"},
                   "_meta" => %{
                     "frontman.dev/agentId" => "executor-id",
                     "frontman.dev/timestamp" => "2026-07-14T12:30:01.000000Z"
                   }
                 }
               }
             } = payload

      refute Map.has_key?(payload["params"]["update"], "timestamp")
    end
  end

  describe "AgentClientProtocol.build_user_message_chunk_notification/5" do
    test "emits one valid attributed notification per unchanged content block" do
      timestamp = ~U[2026-07-14 12:30:00.123456Z]

      content_blocks = [
        %{"type" => "text", "text" => "Hello from user"},
        %{"type" => "image", "data" => "aGVsbG8=", "mimeType" => "image/png"},
        embedded_resource("annotation://node-1", %{"annotation" => true}),
        embedded_resource("page://https://example.com", %{"current_page" => true})
      ]

      payloads =
        Enum.map(content_blocks, fn content ->
          AgentClientProtocol.build_user_message_chunk_notification(
            "session-123",
            "msg-123",
            content,
            "executor-id",
            timestamp
          )
        end)

      Enum.zip(payloads, content_blocks)
      |> Enum.each(fn {payload, content} ->
        ProtocolSchema.validate!(payload, "jsonrpc/notification")
        ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")

        assert get_in(payload, ["params", "update"]) == %{
                 "sessionUpdate" => "user_message_chunk",
                 "messageId" => "msg-123",
                 "content" => content,
                 "_meta" => %{
                   "frontman.dev/agentId" => "executor-id",
                   "frontman.dev/timestamp" => "2026-07-14T12:30:00.123456Z"
                 }
               }
      end)
    end
  end

  defp embedded_resource(uri, metadata) do
    %{
      "type" => "resource",
      "resource" => %{
        "_meta" => metadata,
        "resource" => %{
          "uri" => uri,
          "mimeType" => "text/plain",
          "text" => "context"
        }
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
