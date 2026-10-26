defmodule FrontmanServer.Tasks.Execution.ExecutionSentryTest do
  @moduledoc """
  Tests Swarm execution event Sentry reporting for agent execution failures.

  Tests Gap 3 from issue #474:
  - Failed event triggers Sentry report at :error level
  - Stream-consumption errors are reported as failed executions, not crashes
  """

  use FrontmanServer.DataCase, async: true

  import FrontmanServer.InteractionCase.Helpers,
    only: [assert_receive_interaction: 2]

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServer.Tasks.StreamStallTimeout

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    Sentry.Context.clear_all()
    Logger.reset_metadata([])

    assert {:ok, %{config: config}} = :logger.get_handler_config(:sentry_handler)
    assert config.capture_log_messages
    assert config.capture_level == :error

    scope = user_scope_fixture()
    task_id = task_with_active_turn_fixture(scope, framework: "nextjs").id
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

      assert_receive_interaction(%Interaction.AgentError{kind: "failed"}, _turn_number)

      [report] = pop_all_reports()
      assert report.level == :error
      assert report.tags[:error_type] == "agent_execution_error"
      assert report.tags[:category] == "unknown"
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

      assert_receive_interaction(%Interaction.AgentError{kind: "failed"}, _turn_number)

      [report] = pop_all_reports()
      assert report.level == :error
      assert report.tags[:error_type] == "agent_execution_error"
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

      assert_receive_interaction(
        %Interaction.AgentError{kind: "failed", retryable: true, category: "overload"},
        _turn_number
      )

      assert pop_all_reports() == []
    end

    @tag :capture_log
    test "persists retryable rate limits without Sentry error", %{
      task_id: task_id,
      scope: scope
    } do
      reason = %ReqLLM.Error.API.Request{status: 429, reason: "rate limited"}

      Tasks.handle_swarm_event(scope, task_id, latest_turn_number(task_id), {:failed, reason})

      assert_receive_interaction(
        %Interaction.AgentError{kind: "failed", retryable: true, category: "rate_limit"},
        _turn_number
      )

      assert pop_all_reports() == []
    end
  end

  for {label, reason, category} <- [
        {"provider400", %ReqLLM.Error.API.Request{status: 400, reason: "invalid request"},
         "unknown"},
        {"provider401", %ReqLLM.Error.API.Request{status: 401, reason: "unauthorized"}, "auth"},
        {"provider402", %ReqLLM.Error.API.Request{status: 402, reason: "payment required"},
         "billing"},
        {"provider_quota",
         %ReqLLM.Error.API.Request{
           status: 429,
           reason: "quota exhausted",
           response_body: %{"error" => %{"code" => "insufficient_quota"}}
         }, "quota"},
        {"unknown_model", :unknown_model, "unknown"}
      ] do
    @tag :capture_log
    test "reports nonretryable #{label} failure exactly once", %{
      task_id: task_id,
      scope: scope
    } do
      Tasks.handle_swarm_event(
        scope,
        task_id,
        latest_turn_number(task_id),
        {:failed, unquote(Macro.escape(reason))}
      )

      assert_receive_interaction(
        %Interaction.AgentError{kind: "failed", retryable: false, category: category},
        _turn_number
      )

      assert category == unquote(category)
      [report] = pop_all_reports()
      assert report.level == :error
      assert report.message.formatted == "Agent execution failed"
      assert report.tags[:error_type] == "agent_execution_error"
      assert report.tags[:category] == category
      assert report.tags[:task_id] == task_id
      assert report.tags[:user_id] == scope.user.id
      assert report.extra[:task_id] == task_id
      assert report.extra[:retryable] == false
      assert is_binary(report.extra[:reason])
    end
  end

  defp pop_all_reports do
    Logger.flush()
    Sentry.Test.pop_sentry_reports()
  end
end
