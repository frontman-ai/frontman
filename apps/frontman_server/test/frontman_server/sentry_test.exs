defmodule FrontmanServer.SentryTest do
  use ExUnit.Case, async: false

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    :ok
  end

  describe "Sentry configuration" do
    test "sentry is in test mode" do
      assert Application.get_env(:sentry, :test_mode) == true
    end

    test "sentry DSN is only configured in prod" do
      # DSN is hardcoded in runtime.exs under `if config_env() == :prod`
      # so it should not be set in the test environment
      assert Application.get_env(:sentry, :dsn) == nil
    end
  end

  describe "error capturing" do
    test "captures exception with Sentry.capture_exception/2" do
      try do
        raise "Test error for Sentry"
      rescue
        e -> Sentry.capture_exception(e, stacktrace: __STACKTRACE__)
      end

      [event] = Sentry.Test.pop_sentry_reports()
      # Exception events have the error in the exception field, not message
      [exception] = event.exception
      assert exception.type == "RuntimeError"
      assert exception.value =~ "Test error for Sentry"
    end

    test "captures message with Sentry.capture_message/2" do
      Sentry.capture_message("Test message for Sentry")

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.message.formatted == "Test message for Sentry"
    end

    test "captures exception with custom tags" do
      try do
        raise "Tagged error"
      rescue
        e ->
          Sentry.capture_exception(e,
            stacktrace: __STACKTRACE__,
            tags: %{custom_tag: "custom_value"}
          )
      end

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.tags[:custom_tag] == "custom_value"
    end

    test "captures exception with extra context" do
      try do
        raise "Error with context"
      rescue
        e ->
          Sentry.capture_exception(e,
            stacktrace: __STACKTRACE__,
            extra: %{user_id: "123", action: "test_action"}
          )
      end

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.extra[:user_id] == "123"
      assert event.extra[:action] == "test_action"
    end
  end

  describe "error levels" do
    test "captures message with error level" do
      Sentry.capture_message("Error level message", level: :error)

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.level == :error
    end

    test "captures message with warning level" do
      Sentry.capture_message("Warning level message", level: :warning)

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.level == :warning
    end

    test "captures message with info level" do
      Sentry.capture_message("Info level message", level: :info)

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.level == :info
    end
  end

  describe "multiple events" do
    test "captures multiple independent events" do
      Sentry.capture_message("First message")
      Sentry.capture_message("Second message")
      Sentry.capture_message("Third message")

      reports = Sentry.Test.pop_sentry_reports()
      assert length(reports) == 3

      messages = Enum.map(reports, & &1.message.formatted)
      assert "First message" in messages
      assert "Second message" in messages
      assert "Third message" in messages
    end

    test "pop_sentry_reports clears the reports" do
      Sentry.capture_message("Message 1")

      reports1 = Sentry.Test.pop_sentry_reports()
      assert length(reports1) == 1

      assert [] = Sentry.Test.pop_sentry_reports()

      Sentry.capture_message("Message 2")

      reports3 = Sentry.Test.pop_sentry_reports()
      assert length(reports3) == 1
    end
  end

  describe "integration with tags" do
    test "events include custom tags" do
      Sentry.capture_message("Tag test", tags: %{custom: "value"})

      [event] = Sentry.Test.pop_sentry_reports()
      assert event.tags[:custom] == "value"
    end
  end
end
