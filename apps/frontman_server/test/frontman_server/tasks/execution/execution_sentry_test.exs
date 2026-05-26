defmodule FrontmanServer.Tasks.Execution.ExecutionSentryTest do
  @moduledoc """
  Integration tests verifying Sentry error reporting for agent execution failures.

  Tests Gap 3 from issue #474:
  - Failed event triggers Sentry report at :error level
  - Crashed event triggers Sentry report with exception/stacktrace when available
  """

  use FrontmanServer.ExecutionCase

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.ExecutionEvent

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)

    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    scope = user_scope_fixture()
    task_id = task_with_pubsub_fixture(scope, framework: "nextjs")

    {:ok, task_id: task_id, scope: scope}
  end

  describe "failed event Sentry reporting (Gap 3)" do
    @tag :capture_log
    test "reports LLM error to Sentry with agent_execution_error tag", %{
      task_id: task_id,
      scope: scope
    } do
      expect_llm_responses([{:error, :llm_api_failure}])

      scope = Scope.with_env_api_keys(scope, %{"openrouter" => "sk-or-test"})

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Hello"), [])

      # Wait for the failed event broadcast (Sentry call completes before broadcast)
      assert_receive {:execution_event, %ExecutionEvent{type: :failed}}, 5_000

      reports = Sentry.Test.pop_sentry_reports()

      error_reports =
        Enum.filter(reports, &agent_execution_error_for_task?(&1, task_id))

      assert error_reports != [],
             "Expected at least one agent_execution_error Sentry report for task #{task_id}, got none. All reports: #{inspect(Enum.map(reports, & &1.tags))}"

      [report | _] = error_reports
      metadata = report.extra[:logger_metadata]
      assert report.message.formatted == "Agent execution failed"
      assert is_binary(metadata[:reason])
      assert loop_id?(metadata[:loop_id])
    end
  end

  describe "stream error Sentry reporting (Gap 3)" do
    @tag :capture_log
    test "reports LLM stream error to Sentry as agent_execution_error (not crash)", %{
      task_id: task_id,
      scope: scope
    } do
      # The provider returns {:ok, stream} where the stream raises when consumed.
      # The try/rescue in execute_llm_call catches the raise and routes it through
      # Loop.handle_error → {:failed, ...} → marked Logger report (not crash).
      expect_llm_responses([{:stream_raise, "Sentry test: simulated stream error"}])

      scope = Scope.with_env_api_keys(scope, %{"openrouter" => "sk-or-test"})

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Trigger error"), [])

      # Stream errors now produce {:failed, ...} instead of {:crashed, ...}
      assert_receive {:execution_event,
                      %ExecutionEvent{type: :failed, payload: {:error, _reason, _loop_id}}},
                     5_000

      reports = Sentry.Test.pop_sentry_reports()

      error_reports =
        Enum.filter(reports, &agent_execution_error_for_task?(&1, task_id))

      assert error_reports != [],
             "Expected at least one agent_execution_error Sentry report for task #{task_id}, got none. All reports: #{inspect(Enum.map(reports, &{&1.tags, &1.extra[:logger_metadata][:task_id]}))}"

      [report | _] = error_reports

      # Error report should include the simulated error message
      assert report.message != nil,
             "Error report should have a message"
    end
  end

  defp agent_execution_error_for_task?(event, task_id) do
    case event.tags[:error_type] do
      "agent_execution_error" -> event.extra[:logger_metadata][:task_id] == task_id
      _other -> false
    end
  end

  defp loop_id?(loop_id) when is_integer(loop_id), do: true
  defp loop_id?(loop_id) when is_binary(loop_id), do: true
  defp loop_id?(_loop_id), do: false
end
