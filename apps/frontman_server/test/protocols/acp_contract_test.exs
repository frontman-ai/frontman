defmodule FrontmanServer.Protocols.AcpContractTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents.Agent
  alias FrontmanServer.ProtocolSchema

  describe "AgentClientProtocol.build_initialize_result/0" do
    test "validates against acp/initializeResult schema" do
      payload = AgentClientProtocol.build_initialize_result(agents(), "planner-id")
      ProtocolSchema.validate!(payload, "acp/initializeResult")
    end

    test "advertises Frontman agent attribution v1 under capability metadata" do
      result = AgentClientProtocol.build_initialize_result(agents(), "planner-id")

      assert %{
               "agentCapabilities" => %{
                 "_meta" => %{
                   "frontman.dev" => %{
                     "agentAttribution" => %{"version" => 1},
                     "agents" => [%{"id" => "executor-id"}, %{"id" => "planner-id"}],
                     "defaultAgentId" => "planner-id"
                   }
                 }
               }
             } = result

      ProtocolSchema.validate!(
        get_in(result, ["agentCapabilities", "_meta", "frontman.dev"]),
        "acp/agentAttributionConfigurationMetadata"
      )
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

  describe "AgentClientProtocol.tool_call_create/6" do
    test "validates against acp/sessionUpdateNotification schema" do
      payload =
        AgentClientProtocol.tool_call_create(
          "session-123",
          "tc-1",
          "read_file",
          "other",
          DateTime.utc_now(),
          "pending"
        )

      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")
    end
  end

  describe "AgentClientProtocol.tool_call_update/4" do
    test "with raw input validates against acp/sessionUpdateNotification schema" do
      raw_input = %{"path" => "file.res"}

      payload =
        AgentClientProtocol.tool_call_update("session-123", "tc-1", "pending", nil, raw_input)

      assert get_in(payload, ["params", "update", "rawInput"]) == raw_input
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")
    end

    test "with content validates against acp/sessionUpdateNotification schema" do
      content = [%{"type" => "content", "content" => %{"type" => "text", "text" => "result"}}]

      payload = AgentClientProtocol.tool_call_update("session-123", "tc-1", "completed", content)

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
      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")
    end
  end

  describe "AgentClientProtocol.build_error_notification/4" do
    test "validates against acp/sessionUpdateNotification schema" do
      payload =
        AgentClientProtocol.build_error_notification(
          "session-123",
          "Rate limit exceeded",
          DateTime.utc_now(),
          category: "rate_limit",
          agent_error_id: "agent-error-123"
        )

      ProtocolSchema.validate!(payload, "acp/sessionUpdateNotification")

      assert %{
               "params" => %{
                 "update" => %{"_meta" => %{"frontman.dev/agentErrorId" => "agent-error-123"}}
               }
             } = payload
    end
  end

  describe "AgentClientProtocol.build_state_update_notification/3" do
    test "validates running state against acp/sessionUpdateNotification schema" do
      payload = AgentClientProtocol.build_state_update_notification("session-123", "running")

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
  end

  describe "AgentClientProtocol.agent_info/0" do
    test "validates against acp/implementation schema" do
      payload = AgentClientProtocol.agent_info()
      ProtocolSchema.validate!(payload, "acp/implementation")
    end
  end

  defp agents do
    [
      %Agent{
        id: "executor-id",
        name: "executor",
        display_name: "Executor",
        description: "Executes work",
        color: "#985DF7",
        system: "Execute"
      },
      %Agent{
        id: "planner-id",
        name: "planner",
        display_name: "Planner",
        description: "Plans work",
        color: "#F59E0B",
        system: "Plan"
      }
    ]
  end
end
