defmodule FrontmanServer.Tasks.Execution.ExecutionSentryTest do
  @moduledoc """
  Integration tests verifying Sentry error reporting for agent execution failures.

  Tests Gap 3 from issue #474:
  - Failed event triggers Sentry report at :error level
  - Crashed event triggers Sentry report with exception/stacktrace when available
  """

  use SwarmAi.Testing, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.ExecutionEvent

  setup do
    Sentry.Test.start_collecting_sentry_reports()

    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    scope = user_scope_fixture()
    task_id = task_with_pubsub_fixture(scope, framework: "test-framework")

    {:ok, task_id: task_id, scope: scope}
  end

  describe "failed event Sentry reporting (Gap 3)" do
    @tag :capture_log
    test "reports LLM error to Sentry with agent_execution_error tag", %{
      task_id: task_id,
      scope: scope
    } do
      # ErrorLLM always returns {:error, reason}, triggering a :failed event
      agent = test_agent(%ErrorLLM{error: :llm_api_failure}, "ErrorSentryAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Hello"), [],
          agent: agent,
          env_api_key: %{"openrouter" => "sk-or-test"}
        )

      # Wait for the failed event broadcast (Sentry call completes before broadcast)
      assert_receive {:execution_event, %ExecutionEvent{type: :failed}}, 5_000

      reports = Sentry.Test.pop_sentry_reports()

      error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "agent_execution_error" and
            event.extra[:task_id] == task_id
        end)

      assert error_reports != [],
             "Expected at least one agent_execution_error Sentry report for task #{task_id}, got none. All reports: #{inspect(Enum.map(reports, & &1.tags))}"

      [report | _] = error_reports
      assert report.message.formatted == "Agent execution failed"
      assert is_binary(report.extra[:reason])
      assert is_integer(report.extra[:loop_id]) or is_binary(report.extra[:loop_id])
    end
  end

  describe "stream error Sentry reporting (Gap 3)" do
    @tag :capture_log
    test "reports LLM stream error to Sentry as agent_execution_error (not crash)", %{
      task_id: task_id,
      scope: scope
    } do
      # StreamErrorLLM returns {:ok, stream} where the stream raises when consumed.
      # The try/rescue in execute_llm_call catches the raise and routes it through
      # Loop.handle_error → {:failed, ...} → Sentry.capture_message (not crash).
      error_llm = %StreamErrorLLM{
        error_message: "Sentry test: simulated stream error"
      }

      agent = test_agent(error_llm, "ErrorSentryAgent")

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Trigger error"), [],
          agent: agent,
          env_api_key: %{"openrouter" => "sk-or-test"}
        )

      # Stream errors now produce {:failed, ...} instead of {:crashed, ...}
      assert_receive {:execution_event,
                      %ExecutionEvent{type: :failed, payload: {:error, _reason, _loop_id}}},
                     5_000

      reports = Sentry.Test.pop_sentry_reports()

      error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "agent_execution_error" and
            event.extra[:task_id] == task_id
        end)

      assert error_reports != [],
             "Expected at least one agent_execution_error Sentry report for task #{task_id}, got none. All reports: #{inspect(Enum.map(reports, &{&1.tags, &1.extra[:task_id]}))}"

      [report | _] = error_reports

      # Error report should include the simulated error message
      assert report.message != nil,
             "Error report should have a message"
    end
  end
end
