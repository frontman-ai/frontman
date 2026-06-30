defmodule FrontmanServer.Tasks.Execution.ExecutionSentryTest do
  @moduledoc """
  Tests Swarm execution event Sentry reporting for agent execution failures.

  Tests Gap 3 from issue #474:
  - Failed event triggers Sentry report at :error level
  - Stream-consumption errors are reported as failed executions, not crashes
  """

  use ExUnit.Case, async: false

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.StreamStallTimeout

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    Sentry.Context.clear_all()
    Logger.reset_metadata([])

    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    scope = user_scope_fixture()
    task_id = task_with_active_run_fixture(scope, framework: "nextjs").id
    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, task_topic(task_id))

    {:ok, task_id: task_id, scope: scope}
  end

  describe "failed event Sentry reporting (Gap 3)" do
    @tag :capture_log
    test "reports LLM error to Sentry with agent_execution_error tag", %{
      task_id: task_id,
      scope: scope
    } do
      Tasks.handle_swarm_event(
        scope,
        task_id,
        latest_turn_number(task_id),
        {:failed, :llm_api_failure}
      )

      assert_receive {:interaction, %Interaction.AgentError{kind: "failed"}, _turn_number},
                     5_000

      reports = Sentry.Test.pop_sentry_reports()

      error_reports =
        Enum.filter(reports, &agent_execution_error_for_task?(&1, task_id))

      assert error_reports != [],
             "Expected at least one agent_execution_error Sentry report for task #{task_id}, got none. All reports: #{inspect(Enum.map(reports, & &1.tags))}"

      [report | _] = error_reports
      assert report.message.formatted == "Agent execution failed"
      assert report.tags[:task_id] == task_id
      assert report.tags[:user_id] == scope.user.id
      assert report.extra[:reason] == ":llm_api_failure"
    end
  end

  describe "stream error Sentry reporting (Gap 3)" do
    @tag :capture_log
    test "reports LLM stream error to Sentry as agent_execution_error (not crash)", %{
      task_id: task_id,
      scope: scope
    } do
      reason = %RuntimeError{message: "Sentry test: simulated stream error"}

      Tasks.handle_swarm_event(scope, task_id, latest_turn_number(task_id), {:failed, reason})

      assert_receive {:interaction, %Interaction.AgentError{kind: "failed"}, _turn_number},
                     5_000

      reports = Sentry.Test.pop_sentry_reports()

      error_reports =
        Enum.filter(reports, &agent_execution_error_for_task?(&1, task_id))

      assert error_reports != [],
             "Expected at least one agent_execution_error Sentry report for task #{task_id}, got none. All reports: #{inspect(Enum.map(reports, &{&1.tags, &1.extra[:task_id]}))}"

      [report | _] = error_reports
      assert report.message.formatted == "Agent execution failed"
      assert report.tags[:task_id] == task_id
      assert report.tags[:user_id] == scope.user.id
      assert report.extra[:reason] == "Sentry test: simulated stream error"
    end

    @tag :capture_log
    test "persists wrapped stream stall timeout as retryable overload without Sentry error", %{
      task_id: task_id,
      scope: scope
    } do
      reason = {:exception, %StreamStallTimeout.Error{timeout_ms: 60_000}}

      Tasks.handle_swarm_event(scope, task_id, latest_turn_number(task_id), {:failed, reason})

      assert_receive {:interaction,
                      %Interaction.AgentError{
                        kind: "failed",
                        retryable: true,
                        category: "overload"
                      }, _turn_number},
                     5_000

      reports = Sentry.Test.pop_sentry_reports()

      assert Enum.filter(reports, &agent_execution_error_for_task?(&1, task_id)) == []
    end

    @tag :capture_log
    test "persists retryable rate limits without Sentry error", %{
      task_id: task_id,
      scope: scope
    } do
      reason = %ReqLLM.Error.API.Request{status: 429, reason: "rate limited"}

      Tasks.handle_swarm_event(scope, task_id, latest_turn_number(task_id), {:failed, reason})

      assert_receive {:interaction,
                      %Interaction.AgentError{
                        kind: "failed",
                        retryable: true,
                        category: "rate_limit"
                      }, _turn_number},
                     5_000

      reports = Sentry.Test.pop_sentry_reports()

      assert Enum.filter(reports, &agent_execution_error_for_task?(&1, task_id)) == []
    end
  end

  defp agent_execution_error_for_task?(event, task_id) do
    case event.tags[:error_type] do
      "agent_execution_error" -> event.extra[:task_id] == task_id
      _other -> false
    end
  end
end
