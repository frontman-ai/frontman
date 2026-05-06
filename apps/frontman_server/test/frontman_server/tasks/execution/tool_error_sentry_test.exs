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
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Execution.ToolExecutor
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tools

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)

    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    scope = user_scope_fixture()
    task_id = task_fixture(scope, framework: "nextjs")

    {:ok, task_id: task_id, scope: scope}
  end

  defp backend_exec_opts do
    %{
      backend_tool_modules: Tools.backend_tool_modules(),
      backend_module_map: Map.new(Tools.backend_tool_modules(), &{&1.name(), &1}),
      mcp_tools: [],
      mcp_tool_defs: [],
      llm_opts: [api_key: "test", model: "mock"]
    }
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

      todo_write_module = Enum.find(Tools.backend_tool_modules(), &(&1.name() == "todo_write"))

      result =
        ToolExecutor.run_backend_tool(
          scope,
          todo_write_module,
          task_id,
          backend_exec_opts(),
          tool_call
        )

      assert %SwarmAi.ToolResult{is_error: true} = result

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

      todo_write_module = Enum.find(Tools.backend_tool_modules(), &(&1.name() == "todo_write"))

      result =
        ToolExecutor.run_backend_tool(
          scope,
          todo_write_module,
          task_id,
          backend_exec_opts(),
          tool_call
        )

      assert %SwarmAi.ToolResult{is_error: true} = result

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

      todo_write_module = Enum.find(Tools.backend_tool_modules(), &(&1.name() == "todo_write"))

      _result =
        ToolExecutor.run_backend_tool(
          scope,
          todo_write_module,
          task_id,
          backend_exec_opts(),
          tool_call
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

      todo_write_module = Enum.find(Tools.backend_tool_modules(), &(&1.name() == "todo_write"))

      result =
        ToolExecutor.run_backend_tool(
          scope,
          todo_write_module,
          task_id,
          backend_exec_opts(),
          tool_call
        )

      assert %SwarmAi.ToolResult{is_error: true} = result

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

  # MCP tool timeouts are now handled by SwarmAi.ParallelExecutor via per-tool
  # deadlines (timeout_ms/on_timeout fields on ToolExecution.Await). When on_timeout is
  # :pause_agent, the Runtime dispatches {:paused, {:timeout, ...}} which
  # SwarmDispatcher persists as an AgentPaused interaction — not a Sentry error.

  describe "handle_timeout/5 — :error policy Sentry reporting" do
    @tag :capture_log
    test "persists error ToolResult and reports to Sentry", %{
      task_id: task_id,
      scope: scope
    } do
      tc = %SwarmAi.ToolCall{id: "tc-deadline-1", name: "todo_write", arguments: "{}"}
      ToolExecutor.handle_timeout(scope, task_id, :error, tc, :triggered)

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_result =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: "tc-deadline-1"} -> true
          _ -> false
        end)

      assert tool_result != nil
      assert tool_result.is_error == true
      assert tool_result.result =~ "timed out"

      reports = Sentry.Test.pop_sentry_reports()
      timeout_reports = Enum.filter(reports, &(&1.tags[:error_type] == "tool_timeout"))
      assert length(timeout_reports) == 1
    end

    test "handle_timeout(:triggered) is a no-op for :pause_agent policy", %{
      task_id: task_id,
      scope: scope
    } do
      tc = %SwarmAi.ToolCall{id: "tc-pause-1", name: "some_mcp_tool", arguments: "{}"}
      ToolExecutor.handle_timeout(scope, task_id, :pause_agent, tc, :triggered)

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_result =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: "tc-pause-1"} -> true
          _ -> false
        end)

      assert tool_result == nil
    end
  end
end
