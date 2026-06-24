defmodule FrontmanServer.SentryTest do
  use ExUnit.Case, async: false

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Observability.SentryContext

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    Sentry.Context.clear_all()
    Logger.reset_metadata([])
    :ok
  end

  describe "Sentry configuration" do
    test "sentry is in test mode" do
      assert Application.get_env(:sentry, :test_mode) == true
    end

    test "sentry DSN is only configured in prod" do
      assert Application.get_env(:sentry, :dsn) == nil
    end
  end

  describe "Logger metadata reporting" do
    @tag :capture_log
    test "captures Logger errors with metadata" do
      Logger.error(
        "Logger error with metadata",
        Keyword.new(error_type: "logger_metadata_test", task_id: "task-test")
      )

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.message.formatted == "Logger error with metadata"
      assert event.tags[:error_type] == "logger_metadata_test"
      assert event.tags[:task_id] == "task-test"
      assert event.extra[:logger_metadata][:task_id] == "task-test"
    end

    @tag :capture_log
    test "captures unmarked Logger errors" do
      Logger.error("Unmarked logger error")

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.message.formatted == "Unmarked logger error"
    end

    @tag :capture_log
    test "captures user and task context for logger errors" do
      user = %User{id: Ecto.UUID.generate(), email: "sentry@test.local", name: "Sentry User"}
      task_id = Ecto.UUID.generate()

      Scope.for_user(user)
      |> SentryContext.set_task_scope_context(task_id)

      Logger.error("Logger error with sentry context")

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.tags[:user_id] == user.id
      assert event.tags[:task_id] == task_id
      assert event.extra[:logger_metadata][:user_id] == user.id
      assert event.extra[:logger_metadata][:task_id] == task_id
    end
  end
end
