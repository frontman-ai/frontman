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

  describe "handle_response/3 for tools/list" do
    test "parses interactive tools with pause_agent policy from wire data" do
      request_id = 1
      state = tools_state(request_id)

      result = %{
        "tools" => [
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
        ]
      }

      {new_state, _actions} = MCPInitializer.handle_response(state, request_id, result)

      [question_tool, navigate_tool] = new_state.tools

      assert question_tool.name == "question"
      assert question_tool.on_timeout == :pause_agent
      assert question_tool.timeout_ms == 120_000

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
        "content" => [%{"text" => "Path escapes source root: .", "type" => "text"}],
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

      assert [] = Sentry.Test.pop_sentry_reports()
    end

    test "project structure: does not crash or report to Sentry" do
      request_id = 2
      state = structure_state(request_id)

      result = %{
        "content" => [%{"text" => "Something went wrong", "type" => "text"}],
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
