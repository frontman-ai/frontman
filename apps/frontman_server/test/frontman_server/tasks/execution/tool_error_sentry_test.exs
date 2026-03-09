defmodule FrontmanServer.Tasks.Execution.ToolErrorSentryTest do
  @moduledoc """
  Integration tests verifying Sentry error reporting for tool execution failures.

  Tests the following gaps identified in issue #474:
  - Gap 2: Soft tool errors ({:error, reason}) reported to Sentry
  - Gap 4: MCP tool timeouts reported to Sentry
  - Gap 5: JSON argument parse failures reported to Sentry
  """

  use SwarmAi.Testing, async: false

  import FrontmanServer.InteractionCase.Helpers

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor

  setup do
    Sentry.Test.start_collecting_sentry_reports()

    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "tool_sentry_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    task_id = Ecto.UUID.generate()
    {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

    {:ok, task_id: task_id, scope: scope}
  end

  describe "backend tool soft error Sentry reporting (Gap 2)" do
    test "reports {:error, reason} to Sentry with tool context", %{
      task_id: task_id,
      scope: scope
    } do
      # Calling update on a nonexistent item triggers an {:error, reason} return
      tool_call =
        swarm_tool_call(
          "todo_update",
          Jason.encode!(%{"id" => "nonexistent_id", "status" => "completed"})
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
      assert report.extra[:tool_name] == "todo_update"
      assert report.extra[:tool_call_id] == tool_call.id
      assert report.extra[:task_id] == task_id
      assert is_binary(report.extra[:reason])
    end
  end

  describe "JSON argument parse failure Sentry reporting (Gap 5)" do
    test "reports malformed JSON arguments to Sentry", %{
      task_id: task_id,
      scope: scope
    } do
      # Intentionally malformed JSON
      tool_call = swarm_tool_call("todo_list", "{invalid json!!!}")

      # Execute should still succeed (parse_arguments returns %{} on failure)
      # but Sentry should capture the parse error
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

      assert [report] = parse_error_reports
      assert report.message.formatted == "Tool argument parse failure"
      assert report.extra[:raw_arguments] == "{invalid json!!!}"
      assert is_binary(report.extra[:decode_error])
    end

    test "does not report valid JSON arguments to Sentry", %{
      task_id: task_id,
      scope: scope
    } do
      tool_call = swarm_tool_call("todo_list", Jason.encode!(%{}))

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

    test "truncates long raw arguments in Sentry report", %{
      task_id: task_id,
      scope: scope
    } do
      # Create a long malformed string (> 500 chars) to verify truncation
      long_invalid_json = String.duplicate("x", 1000)

      tool_call = swarm_tool_call("todo_list", long_invalid_json)

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

      assert [report] = parse_error_reports

      # Verify raw_arguments is truncated to 500 chars
      assert String.length(report.extra[:raw_arguments]) == 500
    end
  end

  describe "MCP tool timeout Sentry reporting (Gap 4)" do
    @tag timeout: 70_000

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
