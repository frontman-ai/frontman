defmodule FrontmanServer.Protocols.AcpUpstreamComplianceTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Agents.Agent
  alias FrontmanServer.ProtocolSchema

  @timestamp ~U[2026-07-15 10:00:00.000000Z]

  test "Frontman and generic ACP envelopes validate against pinned upstream v1 schema" do
    catalog = AgentClientProtocol.build_agent_catalog([agent()])

    fixtures = [
      initialize_request(%{"frontman.dev" => %{"agentAttribution" => %{"version" => 1}}}),
      response(2, AgentClientProtocol.build_initialize_result()),
      response(3, AgentClientProtocol.build_session_new_result("session-1", [], catalog)),
      response(4, AgentClientProtocol.build_session_load_result([], catalog)),
      AgentClientProtocol.build_user_message_chunk_notification(
        "session-1",
        "user-1",
        %{"type" => "text", "text" => "Hello"},
        "executor-id",
        @timestamp
      ),
      AgentClientProtocol.build_agent_message_chunk_notification(
        "session-1",
        "Hello back",
        @timestamp,
        "turn-1:0",
        "executor-id"
      ),
      initialize_request(%{"other.vendor/feature" => %{"enabled" => true}}),
      initialize_request(nil)
    ]

    Enum.each(fixtures, &ProtocolSchema.validate_upstream_acp!/1)
  end

  test "draft adapter preserves upstream envelope and known-update constraints" do
    assert ProtocolSchema.upstream_acp_definition_valid?(
             FrontmanServer.CurrentPageContext.to_content_blocks(%{url: "http://localhost"})
             |> hd(),
             "ContentBlock"
           )

    refute ProtocolSchema.upstream_acp_valid?(%{
             "jsonrpc" => "1.0",
             "id" => 1,
             "method" => "initialize",
             "params" => %{"protocolVersion" => 1}
           })

    assert ProtocolSchema.upstream_acp_definition_valid?(
             %{
               "sessionUpdate" => "agent_message_chunk",
               "content" => %{"type" => "text", "text" => "valid"}
             },
             "SessionUpdate"
           )

    refute ProtocolSchema.upstream_acp_definition_valid?(
             %{"sessionUpdate" => "agent_message_chunk"},
             "SessionUpdate"
           )
  end

  defp initialize_request(metadata) do
    client_capabilities = %{
      "fs" => %{"readTextFile" => true, "writeTextFile" => true},
      "terminal" => true
    }

    client_capabilities =
      case metadata do
        nil -> client_capabilities
        metadata -> Map.put(client_capabilities, "_meta", metadata)
      end

    %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => %{
        "protocolVersion" => 1,
        "clientCapabilities" => client_capabilities,
        "clientInfo" => %{"name" => "frontman", "version" => "test"}
      }
    }
  end

  defp response(id, result),
    do: %{"jsonrpc" => "2.0", "id" => id, "result" => result}

  defp agent do
    %Agent{
      id: "executor-id",
      name: "executor",
      display_name: "Executor",
      description: "Executes work",
      color: "#985DF7",
      system: "Execute"
    }
  end
end
