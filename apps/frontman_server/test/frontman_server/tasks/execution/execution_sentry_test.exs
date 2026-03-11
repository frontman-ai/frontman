defmodule FrontmanServer.Tasks.Execution.ExecutionSentryTest do
  @moduledoc """
  Integration tests verifying Sentry error reporting for agent execution failures.

  Tests Gap 3 from issue #474:
  - on_error callback reports to Sentry at :error level
  - on_crash callback reports to Sentry with exception/stacktrace when available
  """

  use SwarmAi.Testing, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks

  setup do
    Sentry.Test.start_collecting_sentry_reports()

    # Allow the ExecutionMonitor process to report Sentry events back to the
    # test process. The on_crash callback runs inside ExecutionMonitor (a
    # long-lived GenServer) which has no $callers chain to the test process.
    monitor_pid =
      Process.whereis(SwarmAi.Runtime.monitor_name(FrontmanServer.AgentRuntime))

    if monitor_pid do
      try do
        Sentry.Test.allow_sentry_reports(self(), monitor_pid)
      rescue
        # The ExecutionMonitor is a singleton GenServer shared across all test
        # partitions. When another test file (e.g. task_channel_sentry_test.exs)
        # runs in the same partition and already allowed this PID, the Sentry
        # test sandbox raises "this PID is already allowed to access key :events".
        # This is benign — the monitor can still report events to our test
        # process. The actual Sentry assertions below will catch real failures.
        e in RuntimeError ->
          unless e.message =~ "already allowed" do
            reraise e, __STACKTRACE__
          end
      end
    end

    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    {:ok, user} =
      Accounts.register_user(%{
        email: "exec_sentry_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    task_id = Ecto.UUID.generate()
    {:ok, ^task_id} = Tasks.create_task(scope, task_id, "test-framework")

    Phoenix.PubSub.subscribe(FrontmanServer.PubSub, Tasks.topic(task_id))

    {:ok, task_id: task_id, scope: scope}
  end

  describe "on_error Sentry reporting (Gap 3)" do
    test "reports LLM error to Sentry with agent_execution_error tag", %{
      task_id: task_id,
      scope: scope
    } do
      # ErrorLLM always returns {:error, reason}, triggering the on_error callback
      agent = test_agent(%ErrorLLM{error: :llm_api_failure}, "ErrorSentryAgent")

      user_content = [%{"type" => "text", "text" => "Hello"}]
      {:ok, _} = Tasks.add_user_message(scope, task_id, user_content, [], agent: agent)

      # Wait for the agent error broadcast (Sentry call completes before broadcast)
      assert_receive {:agent_error, _message}, 5_000

      reports = Sentry.Test.pop_sentry_reports()

      error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "agent_execution_error"
        end)

      assert error_reports != [],
             "Expected at least one agent_execution_error Sentry report, got none. All reports: #{inspect(Enum.map(reports, & &1.tags))}"

      [report | _] = error_reports
      assert report.message.formatted == "Agent execution failed"
      assert report.extra[:task_id] == task_id
      assert is_binary(report.extra[:reason])
      assert is_integer(report.extra[:loop_id]) or is_binary(report.extra[:loop_id])
    end
  end

  describe "on_crash Sentry reporting (Gap 3)" do
    test "reports LLM stream crash to Sentry with agent_crash tag", %{
      task_id: task_id,
      scope: scope
    } do
      # StreamErrorLLM returns {:ok, stream} where the stream raises when consumed.
      # This triggers on_crash (not on_error) because the execution process crashes.
      error_llm = %StreamErrorLLM{
        error_message: "Sentry test: simulated stream crash"
      }

      agent = test_agent(error_llm, "CrashSentryAgent")

      user_content = [%{"type" => "text", "text" => "Trigger crash"}]
      {:ok, _} = Tasks.add_user_message(scope, task_id, user_content, [], agent: agent)

      # Wait for the crash error broadcast (Sentry call completes before broadcast)
      assert_receive {:agent_error, _message}, 5_000

      reports = Sentry.Test.pop_sentry_reports()

      crash_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "agent_crash"
        end)

      assert crash_reports != [],
             "Expected at least one agent_crash Sentry report, got none. All reports: #{inspect(Enum.map(reports, &{&1.tags, &1.message}))}"

      [report | _] = crash_reports
      assert report.extra[:task_id] == task_id

      # Crash reports should include exception info or a message
      has_exception = report.exception != nil and report.exception != []
      has_message = report.message != nil

      assert has_exception or has_message,
             "Crash report should have either an exception or a message"
    end
  end
end
