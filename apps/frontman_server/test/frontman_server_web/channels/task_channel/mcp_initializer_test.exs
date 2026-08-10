defmodule FrontmanServerWeb.TaskChannel.MCPInitializerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias FrontmanServerWeb.TaskChannel.MCPInitializer

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    :ok
  end

  defp tools_state(request_id) do
    %{
      status: :loading_tools,
      task_id: "test_task",
      scope: %FrontmanServer.Accounts.Scope{user: %FrontmanServer.Accounts.User{id: 1}},
      mcp_init_request_id: nil,
      tools_request_id: request_id,
      project_rules_request_id: nil,
      project_structure_request_id: nil,
      mcp_capabilities: %{},
      mcp_server_info: %{},
      load_project_context: true,
      tools: nil
    }
  end

  defp rules_state(request_id) do
    %{
      status: :loading_project_rules,
      task_id: "test_task",
      scope: %FrontmanServer.Accounts.Scope{user: %FrontmanServer.Accounts.User{id: 1}},
      mcp_init_request_id: nil,
      tools_request_id: nil,
      project_rules_request_id: request_id,
      project_structure_request_id: nil,
      mcp_capabilities: %{},
      mcp_server_info: %{},
      load_project_context: true,
      tools: []
    }
  end

  defp structure_state(request_id) do
    %{
      status: :loading_project_structure,
      task_id: "test_task",
      scope: %FrontmanServer.Accounts.Scope{user: %FrontmanServer.Accounts.User{id: 1}},
      mcp_init_request_id: nil,
      tools_request_id: nil,
      project_rules_request_id: nil,
      project_structure_request_id: request_id,
      mcp_capabilities: %{},
      mcp_server_info: %{},
      load_project_context: true,
      tools: []
    }
  end

  describe "discovery" do
    test "starts with server/discover and no initialize notification" do
      {state, actions} = MCPInitializer.start("test_task", %{}, :nextjs)

      assert state.status == :discovering_mcp
      assert [{:push_mcp, request}] = actions
      assert request["method"] == "server/discover"
      refute Enum.any?(actions, &match?({:push_mcp, %{"method" => "initialize"}}, &1))

      refute Enum.any?(
               actions,
               &match?({:push_mcp, %{"method" => "notifications/initialized"}}, &1)
             )
    end

    test "requires compatible version and execution-context capability before tools/list" do
      {state, _actions} = MCPInitializer.start("test_task", %{}, :nextjs)

      result = %{
        "resultType" => "discovery",
        "supportedVersions" => [ModelContextProtocol.protocol_version()],
        "capabilities" => %{"tools" => %{}},
        "ttlMs" => 0,
        "cacheScope" => "private"
      }

      {failed_state, actions} =
        MCPInitializer.handle_response(state, state.mcp_init_request_id, result)

      assert failed_state.status == :failed
      assert actions == [{:initialization_failed, "missing_required_server_extension"}]
      refute Enum.any?(actions, &match?({:push_mcp, %{"method" => "tools/list"}}, &1))
    end
  end

  describe "handle_response/3 for tools/list" do
    test "loads standard tools with conservative internal policy" do
      request_id = 1
      state = tools_state(request_id)

      result = %{
        "tools" => [
          %{
            "name" => "question",
            "description" => "Ask the user a question",
            "inputSchema" => %{"type" => "object", "properties" => %{}},
            "annotations" => %{"readOnlyHint" => true}
          },
          %{
            "name" => "navigate",
            "description" => "Navigate to a URL",
            "inputSchema" => %{"type" => "object", "properties" => %{}}
          }
        ]
      }

      {new_state, _actions} = MCPInitializer.handle_response(state, request_id, result)

      [question_tool, navigate_tool] = new_state.tools

      assert question_tool.name == "question"
      assert question_tool.on_timeout == :error
      assert question_tool.timeout_ms == 600_000
      assert question_tool.annotations == %{"readOnlyHint" => true}

      assert navigate_tool.name == "navigate"
      assert navigate_tool.on_timeout == :error
      assert navigate_tool.timeout_ms == 600_000
    end
  end

  describe "handle_response/3 with tool-level errors (isError: true)" do
    test "project rules: does not crash or report to Sentry" do
      request_id = 1
      state = rules_state(request_id)

      result = %{
        "resultType" => "complete",
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
        "resultType" => "complete",
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
        "resultType" => "complete",
        "content" => [%{"text" => ~s({"key": "value"}), "type" => "text"}]
      }

      {new_state, _actions} = MCPInitializer.handle_response(state, request_id, result)

      assert new_state.status == :loading_project_structure
    end
  end
end
