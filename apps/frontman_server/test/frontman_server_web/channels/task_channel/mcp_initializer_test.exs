defmodule FrontmanServerWeb.TaskChannel.MCPInitializerTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias FrontmanServerWeb.ChannelCase
  alias FrontmanServerWeb.TaskChannel.MCPInitializer

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    :ok
  end

  defp discovery_result(overrides), do: ChannelCase.mcp_discovery_result(overrides)

  defp state(overrides) do
    scope = %FrontmanServer.Accounts.Scope{user: %FrontmanServer.Accounts.User{id: 1}}
    {state, _actions} = MCPInitializer.start("test_task", scope, :nextjs)
    Map.merge(state, overrides)
  end

  defp discovery_state,
    do: MCPInitializer.start("test_task", %FrontmanServer.Accounts.Scope{}, :nextjs)

  defp tools_result(tools, overrides \\ %{}), do: ChannelCase.mcp_tools_result(tools, overrides)

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

    result = discovery_result(%{"ttlMs" => 2_592_000_000})

    {_new_state, [{:push_mcp, tools_request}]} =
      MCPInitializer.handle_response(state, state.discovery_request_id, result)

    assert tools_request["method"] == "tools/list"
    assert tools_request["params"] == ModelContextProtocol.tools_list_params()
  end

  test "fails initialization for incompatible protocol or extension versions" do
    incompatible_results = [
      discovery_result(%{"supportedVersions" => ["2025-11-25"]}),
      discovery_result(%{
        "capabilities" => %{
          "tools" => %{"listChanged" => false},
          "extensions" => %{
            "ai.frontman/execution-context" => %{"version" => 2}
          }
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

  describe "handle_response/3 for tools/list" do
    test "requests every tools page before continuing initialization" do
      state = tools_state(1)

      first_page =
        tools_result(
          [%{"name" => "first", "inputSchema" => %{"type" => "object"}}],
          %{"nextCursor" => "page-2"}
        )

      assert {new_state = %{status: :loading_tools, tools: [first]}, [{:push_mcp, request}]} =
               MCPInitializer.handle_response(state, 1, first_page)

      assert first.name == "first"
      assert request["method"] == "tools/list"
      assert request["params"]["cursor"] == "page-2"

      second_page =
        tools_result([%{"name" => "second", "inputSchema" => %{"type" => "object"}}])

      assert {%{status: :loading_project_rules, tools: [first, second]}, [{:push_mcp, _}]} =
               MCPInitializer.handle_response(new_state, request["id"], second_page)

      assert {first.name, second.name} == {"first", "second"}
    end

    test "fails initialization when a tools cursor repeats" do
      state = tools_state(1)
      first_page = tools_result([], %{"nextCursor" => "same-cursor"})

      assert {new_state, [{:push_mcp, request}]} =
               MCPInitializer.handle_response(state, 1, first_page)

      repeated_page = tools_result([], %{"nextCursor" => "same-cursor"})

      assert {%{status: :failed}, [{:initialization_failed, message}]} =
               MCPInitializer.handle_response(new_state, request["id"], repeated_page)

      assert message =~ "repeated cursor"
    end

    test "crashes with context when tools pagination exceeds its bound" do
      seen_tool_cursors = 1..99 |> Enum.map(&"page-#{&1}") |> MapSet.new()
      state = %{tools_state(1) | seen_tool_cursors: seen_tool_cursors}
      page = tools_result([], %{"nextCursor" => "page-100"})

      assert_raise RuntimeError, ~r/MCP tools\/list exceeded 100 pages/, fn ->
        MCPInitializer.handle_response(state, 1, page)
      end
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
  end

  describe "handle_response/3 with tool-level errors (isError: true)" do
    test "advances initialization without reporting private tool errors" do
      for {request_id, state, step, next_status} <- [
            {1, rules_state(1), "project_rules", :loading_project_structure},
            {2, structure_state(2), "project_structure", :ready}
          ] do
        marker = "private-#{step}-marker"

        log =
          capture_log(fn ->
            {new_state, [_action]} =
              MCPInitializer.handle_response(state, request_id, %{
                "resultType" => "complete",
                "content" => [%{"text" => marker, "type" => "text"}],
                "isError" => true
              })

            assert new_state.status == next_status
          end)

        assert log =~ "Tool error loading #{step}"
        refute log =~ marker
      end

      assert Sentry.Test.pop_sentry_reports() == []
    end
  end
end
