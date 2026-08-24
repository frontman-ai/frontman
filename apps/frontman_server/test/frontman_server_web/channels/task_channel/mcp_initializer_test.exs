defmodule FrontmanServerWeb.TaskChannel.MCPInitializerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias FrontmanServerWeb.TaskChannel.MCPInitializer

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    :ok
  end

  defp discovery_result(overrides \\ %{}) do
    Map.merge(
      %{
        "resultType" => "complete",
        "supportedVersions" => [ModelContextProtocol.protocol_version()],
        "capabilities" => %{
          "tools" => %{"listChanged" => false},
          "extensions" => %{
            "ai.frontman/execution-context" => %{"version" => 1}
          }
        },
        "ttlMs" => 0,
        "cacheScope" => "private",
        "_meta" => %{
          "io.modelcontextprotocol/serverInfo" => %{"name" => "browser", "version" => "1.0.0"}
        }
      },
      overrides
    )
  end

  defp state(overrides) do
    scope = %FrontmanServer.Accounts.Scope{user: %FrontmanServer.Accounts.User{id: 1}}
    {state, _actions} = MCPInitializer.start("test_task", scope, :nextjs)
    Map.merge(state, overrides)
  end

  defp discovery_state,
    do: MCPInitializer.start("test_task", %FrontmanServer.Accounts.Scope{}, :nextjs)

  defp tools_result(tools, overrides \\ %{}) do
    Map.merge(
      %{
        "resultType" => "complete",
        "tools" => tools,
        "ttlMs" => 0,
        "cacheScope" => "private",
        "_meta" => %{
          "io.modelcontextprotocol/serverInfo" => %{
            "name" => "browser",
            "version" => "1.0.0"
          }
        }
      },
      overrides
    )
  end

  defp tools_state(request_id),
    do: state(%{status: :loading_tools, discovery_request_id: nil, tools_request_id: request_id})

  defp rules_state(request_id),
    do:
      state(%{
        status: :loading_project_rules,
        discovery_request_id: nil,
        project_rules_request_id: request_id
      })

  defp structure_state(request_id),
    do:
      state(%{
        status: :loading_project_structure,
        discovery_request_id: nil,
        project_structure_request_id: request_id
      })

  test "discovers the server then requests one tools page without an initialized notification" do
    {state, [{:push_mcp, discovery}]} =
      MCPInitializer.start("test_task", %FrontmanServer.Accounts.Scope{}, :nextjs)

    assert discovery["method"] == "server/discover"

    assert discovery["params"]["_meta"]["io.modelcontextprotocol/protocolVersion"] ==
             "2026-07-28"

    result = discovery_result()

    {new_state, [{:push_mcp, tools_request}]} =
      MCPInitializer.handle_response(state, state.discovery_request_id, result)

    assert new_state.mcp_server_info ==
             result["_meta"]["io.modelcontextprotocol/serverInfo"]

    assert tools_request["method"] == "tools/list"
    assert tools_request["params"] == ModelContextProtocol.request_params()
  end

  test "fails initialization for a malformed discovery response" do
    {state, _actions} = discovery_state()

    assert {%{status: :failed},
            [{:initialization_failed, "Invalid or incompatible MCP discovery response"}]} =
             MCPInitializer.handle_response(
               state,
               state.discovery_request_id,
               %{"resultType" => "complete"}
             )
  end

  test "fails initialization for malformed present server info" do
    {state, _actions} = discovery_state()
    result = discovery_result(%{"_meta" => %{"io.modelcontextprotocol/serverInfo" => %{}}})

    assert {%{status: :failed}, [{:initialization_failed, message}]} =
             MCPInitializer.handle_response(state, state.discovery_request_id, result)

    assert message =~ "incompatible MCP discovery"
  end

  test "fails initialization for incompatible protocol or extension versions" do
    incompatible_results = [
      %{discovery_result() | "ttlMs" => -1},
      discovery_result(%{"supportedVersions" => ["2025-11-25"]}),
      discovery_result(%{
        "capabilities" => %{
          "tools" => %{"listChanged" => false},
          "extensions" => %{
            "ai.frontman/execution-context" => %{"version" => 2}
          }
        }
      }),
      discovery_result(%{
        "capabilities" => %{
          "tools" => %{"listChanged" => "no"},
          "extensions" => %{"ai.frontman/execution-context" => %{"version" => 1}}
        }
      })
    ]

    Enum.each(incompatible_results, fn result ->
      {state, _actions} = discovery_state()

      assert {%{status: :failed}, [{:initialization_failed, message}]} =
               MCPInitializer.handle_response(state, state.discovery_request_id, result)

      assert message =~ "incompatible MCP discovery"
    end)
  end

  test "accepts optional discovery fields and unrelated extension settings" do
    {state, _actions} = discovery_state()

    result =
      discovery_result(%{
        "capabilities" => %{
          "tools" => %{},
          "extensions" => %{
            "ai.frontman/execution-context" => %{"version" => 1},
            "io.modelcontextprotocol/ui" => %{"mimeTypes" => ["text/html"]}
          }
        },
        "ttlMs" => 0.5,
        "cacheScope" => "public",
        "_meta" => %{}
      })

    assert {%{status: :loading_tools, mcp_server_info: nil}, [{:push_mcp, request}]} =
             MCPInitializer.handle_response(state, state.discovery_request_id, result)

    assert request["method"] == "tools/list"
  end

  describe "handle_response/3 for tools/list" do
    test "parses interactive tools with pause_agent policy from wire data" do
      request_id = 1
      state = tools_state(request_id)

      result =
        tools_result([
          %{
            "name" => "question",
            "description" => "Ask the user a question",
            "inputSchema" => %{"type" => "object", "properties" => %{}},
            "executionMode" => "interactive"
          },
          %{
            "name" => "navigate",
            "description" => "Navigate to a URL",
            "inputSchema" => %{"type" => "object", "properties" => %{}}
          }
        ])

      {new_state, _actions} = MCPInitializer.handle_response(state, request_id, result)

      [question_tool, navigate_tool] = new_state.tools

      assert question_tool.name == "question"
      assert question_tool.on_timeout == :pause_agent
      assert question_tool.timeout_ms == 120_000

      assert navigate_tool.name == "navigate"
      assert navigate_tool.on_timeout == :error
      assert navigate_tool.timeout_ms == 600_000
    end

    test "fails initialization for malformed tools" do
      invalid_results = [
        tools_result([%{"name" => "missing tool fields"}]),
        %{tools_result([]) | "ttlMs" => -1}
      ]

      Enum.each(invalid_results, fn result ->
        state = tools_state(1)

        assert {%{status: :failed}, [{:initialization_failed, "Invalid MCP tools/list response"}]} =
                 MCPInitializer.handle_response(state, 1, result)
      end)
    end

    test "accepts optional tool fields in a one-page catalog" do
      result =
        tools_result(
          [
            %{
              "name" => "question",
              "description" => "Ask a question",
              "inputSchema" => %{"type" => "object"}
            }
          ],
          %{
            "ttlMs" => 1.5,
            "cacheScope" => "public",
            "_meta" => %{}
          }
        )

      state = tools_state(1)

      assert {%{status: :loading_project_rules, tools: tools}, [{:push_mcp, _request}]} =
               MCPInitializer.handle_response(state, 1, result)

      assert Enum.map(tools, & &1.name) == ["question"]
      assert Enum.map(tools, & &1.description) == ["Ask a question"]
    end

    test "ignores stale responses after terminal failure" do
      state = tools_state(1)

      {failed_state, [{:initialization_failed, _message}]} =
        MCPInitializer.handle_response(state, 1, tools_result([%{"name" => "invalid"}]))

      assert failed_state.status == :failed
      assert failed_state.discovery_request_id == nil
      assert failed_state.tools_request_id == nil
      assert failed_state.project_rules_request_id == nil
      assert failed_state.project_structure_request_id == nil

      assert {^failed_state, []} =
               MCPInitializer.handle_response(failed_state, 1, tools_result([]))

      assert {^failed_state, []} =
               MCPInitializer.handle_error(failed_state, 1, %{"message" => "late error"})
    end

    test "ignores duplicate responses after initialization completes" do
      state = %{tools_state(1) | load_project_context: false}

      {ready_state, [{:push_acp, _notification}, {:initialization_complete, _data}]} =
        MCPInitializer.handle_response(state, 1, tools_result([]))

      assert ready_state.status == :ready
      assert {^ready_state, []} = MCPInitializer.handle_response(ready_state, 1, tools_result([]))
    end
  end

  describe "handle_response/3 with tool-level errors (isError: true)" do
    test "project rules: does not crash or report to Sentry" do
      request_id = 1
      state = rules_state(request_id)

      result = %{
        "content" => [%{"text" => "private-project-rules-marker", "type" => "text"}],
        "isError" => true
      }

      log =
        capture_log(fn ->
          {new_state, actions} = MCPInitializer.handle_response(state, request_id, result)

          assert new_state.status == :loading_project_structure

          assert Enum.any?(actions, fn
                   {:push_mcp, _} -> true
                   _ -> false
                 end)
        end)

      assert log =~ "Tool error loading project_rules"
      refute log =~ "private-project-rules-marker"

      assert [] = Sentry.Test.pop_sentry_reports()
    end

    test "project structure: does not crash or report to Sentry" do
      request_id = 2
      state = structure_state(request_id)

      result = %{
        "content" => [%{"text" => "private-project-structure-marker", "type" => "text"}],
        "isError" => true
      }

      log =
        capture_log(fn ->
          {new_state, actions} = MCPInitializer.handle_response(state, request_id, result)

          assert new_state.status == :ready

          assert Enum.any?(actions, fn
                   {:initialization_complete, _} -> true
                   _ -> false
                 end)
        end)

      assert log =~ "Tool error loading project_structure"
      refute log =~ "private-project-structure-marker"

      assert [] = Sentry.Test.pop_sentry_reports()
    end
  end

  describe "handle_response/3 with unhandled decode results" do
    test "project rules: handles JSON that decodes to a map (not a list)" do
      request_id = 1
      state = rules_state(request_id)

      result = %{
        "content" => [%{"text" => ~s({"key": "value"}), "type" => "text"}]
      }

      {new_state, _actions} = MCPInitializer.handle_response(state, request_id, result)

      assert new_state.status == :loading_project_structure
    end
  end
end
