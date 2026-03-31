defmodule FrontmanServerWeb.TaskChannel.MCPInitializerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias FrontmanServerWeb.TaskChannel.MCPInitializer

  setup do
    Sentry.Test.start_collecting_sentry_reports()
    :ok
  end

  # A minimal state in the project_rules loading phase
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
      tools: []
    }
  end

  # A minimal state in the project_structure loading phase
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
      tools: []
    }
  end

  describe "handle_response/3 with tool-level errors (isError: true)" do
    test "project rules: does not crash and reports to Sentry" do
      request_id = 1
      state = rules_state(request_id)

      # This is the exact payload from the Sentry issue — a successful JSON-RPC
      # response where the tool itself returned an error.
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

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.message.formatted == "MCP tool error during initialization"
      assert event.level == :warning
      assert event.tags[:init_step] == "project_rules"
      assert event.extra[:tool_name] == "load_agent_instructions"
      assert event.extra[:error_text] =~ "Path escapes source root"
    end

    test "project structure: does not crash and reports to Sentry" do
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

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.message.formatted == "MCP tool error during initialization"
      assert event.tags[:init_step] == "project_structure"
      assert event.extra[:tool_name] == "list_tree"
    end
  end

  describe "handle_response/3 with unhandled decode results" do
    test "project rules: handles JSON that decodes to a map (not a list)" do
      request_id = 1
      state = rules_state(request_id)

      # JSON decodes successfully but to a map, not a list — the `when is_list` guard
      # in the `with` block rejects it, and there's no matching `else` clause.
      result = %{
        "content" => [%{"text" => ~s({"key": "value"}), "type" => "text"}]
      }

      {new_state, _actions} = MCPInitializer.handle_response(state, request_id, result)

      assert new_state.status == :loading_project_structure
    end
  end
end
