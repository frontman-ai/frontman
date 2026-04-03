defmodule FrontmanServer.Tasks.Execution.ToolErrorSentryTest do
  @moduledoc """
  Integration tests verifying Sentry error reporting for tool execution failures.

  Tests the following gaps identified in issue #474:
  - Gap 2: Soft tool errors ({:error, reason}) reported to Sentry
  - Gap 4: MCP tool timeouts reported to Sentry
  - Gap 5: JSON argument parse failures reported to Sentry
  """

  use SwarmAi.Testing, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.InteractionCase.Helpers
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Tasks.Execution.ToolExecutor

  setup do
    Sentry.Test.start_collecting_sentry_reports()

    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    scope = user_scope_fixture()
    task_id = task_fixture(scope, framework: "test-framework")

    {:ok, task_id: task_id, scope: scope}
  end

  describe "backend tool soft error Sentry reporting (Gap 2)" do
    @tag :capture_log
    test "reports {:error, reason} to Sentry with tool context", %{
      task_id: task_id,
      scope: scope
    } do
      # Sending an invalid status triggers an {:error, reason} return
      tool_call =
        swarm_tool_call(
          "todo_write",
          Jason.encode!(%{
            "todos" => [
              %{"content" => "Task", "active_form" => "Working", "status" => "invalid_status"}
            ]
          })
        )

      result =
        ToolExecutor.execute(scope, tool_call, task_id,
          mcp_tools: [],
          llm_opts: [api_key: "test", model: "mock"]
        )

      assert {:error, _reason} = result

      # Verify Sentry captured the tool error
      reports = Sentry.Test.pop_sentry_reports()

      tool_error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "tool_soft_error"
        end)

      assert tool_error_reports != [],
             "Expected at least one tool_soft_error Sentry report, got none"

      [report | _] = tool_error_reports
      assert report.message.formatted == "Tool execution failed"
      assert report.extra[:tool_name] == "todo_write"
      assert report.extra[:tool_call_id] == tool_call.id
      assert report.extra[:task_id] == task_id
      assert is_binary(report.extra[:reason])
    end
  end

  describe "JSON argument parse failure Sentry reporting (Gap 5)" do
    @tag :capture_log
    test "reports malformed JSON arguments to Sentry", %{
      task_id: task_id,
      scope: scope
    } do
      # Intentionally malformed JSON
      tool_call = swarm_tool_call("todo_write", "{invalid json!!!}")

      # Parse failure should propagate as {:error, _} — the tool must not execute
      result =
        ToolExecutor.execute(scope, tool_call, task_id,
          mcp_tools: [],
          llm_opts: [api_key: "test", model: "mock"]
        )

      assert {:error, _reason} = result

      reports = Sentry.Test.pop_sentry_reports()

      parse_error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "tool_parse_error"
        end)

      assert [report] = parse_error_reports
      assert report.message.formatted == "Tool argument parse failure"
      assert report.tags[:tool_name] == "todo_write"
      assert report.extra[:tool_name] == "todo_write"
      assert report.extra[:raw_arguments] == "{invalid json!!!}"
      assert is_binary(report.extra[:decode_error])

      # No duplicate "tool execution failed" report — parse_arguments handles its own reporting
      soft_error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "tool_soft_error"
        end)

      assert soft_error_reports == []
    end

    test "does not report valid JSON arguments to Sentry", %{
      task_id: task_id,
      scope: scope
    } do
      tool_call = swarm_tool_call("todo_write", Jason.encode!(%{"todos" => []}))

      _result =
        ToolExecutor.execute(scope, tool_call, task_id,
          mcp_tools: [],
          llm_opts: [api_key: "test", model: "mock"]
        )

      reports = Sentry.Test.pop_sentry_reports()

      parse_error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "tool_parse_error"
        end)

      assert parse_error_reports == [],
             "Expected no parse error reports for valid JSON, got #{length(parse_error_reports)}"
    end

    @tag :capture_log
    test "truncates long raw arguments in Sentry report", %{
      task_id: task_id,
      scope: scope
    } do
      # Create a long malformed string (> 500 chars) to verify truncation
      long_invalid_json = String.duplicate("x", 1000)

      tool_call = swarm_tool_call("todo_write", long_invalid_json)

      assert {:error, _} =
               ToolExecutor.execute(scope, tool_call, task_id,
                 mcp_tools: [],
                 llm_opts: [api_key: "test", model: "mock"]
               )

      reports = Sentry.Test.pop_sentry_reports()

      parse_error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "tool_parse_error"
        end)

      assert [report] = parse_error_reports

      # Verify raw_arguments is truncated to 500 chars
      assert String.length(report.extra[:raw_arguments]) == 500
    end
  end

  describe "MCP tool timeout Sentry reporting (Gap 4)" do
    @tag timeout: 70_000
    @tag :capture_log

    test "reports MCP tool timeout to Sentry", %{
      task_id: task_id,
      scope: scope
    } do
      tool_call = swarm_tool_call("fake_mcp_tool")

      # Register as MCP tool manually (since fake_mcp_tool won't be found as backend)
      Registry.register(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call.id}, %{
        caller_pid: self()
      })

      # Spawn a process that calls execute_mcp_tool path and waits for timeout
      # We override the timeout by calling execute directly which will route to MCP
      test_pid = self()

      task =
        Task.async(fn ->
          result =
            ToolExecutor.execute(scope, tool_call, task_id,
              mcp_tools: [],
              llm_opts: [api_key: "test", model: "mock"]
            )

          send(test_pid, {:tool_result, result})
        end)

      # Wait for the timeout (60s) + some buffer
      assert_receive {:tool_result, {:error, timeout_msg}}, 65_000
      assert timeout_msg =~ "Tool timeout"

      Task.await(task, 5_000)

      # Verify Sentry captured the timeout
      reports = Sentry.Test.pop_sentry_reports()

      timeout_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "tool_timeout"
        end)

      assert [report] = timeout_reports
      assert report.message.formatted == "MCP tool timeout"
      assert report.extra[:tool_name] == "fake_mcp_tool"
      assert report.extra[:task_id] == task_id
      assert report.extra[:timeout_ms] == 60_000
    end
  end
end
