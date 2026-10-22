defmodule FrontmanServer.SentryTest do
  use ExUnit.Case, async: false

  require Logger

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Accounts.User
  alias FrontmanServer.Observability.Sentry, as: SentryReporting
  alias FrontmanServer.Observability.SentryContext
  alias FrontmanServer.Tasks.InteractionSchema

  setup do
    Sentry.Test.setup_sentry(dedup_events: false)
    Sentry.Context.clear_all()
    Logger.reset_metadata([])
    :ok
  end

  describe "Sentry configuration" do
    test "leaves unrelated events unchanged" do
      event = Sentry.Event.transform_exception(%RuntimeError{message: "unrelated"}, [])
      assert SentryReporting.before_send(event) == event
    end

    test "sentry is in test mode" do
      assert Application.get_env(:sentry, :test_mode) == true
    end

    test "sentry DSN is only configured in prod" do
      assert Application.get_env(:sentry, :dsn) == nil
    end
  end

  describe "Logger metadata reporting" do
    test "serializes parameterized type metadata from cast errors" do
      type = Ecto.ParameterizedType.init(Ecto.Enum, values: [:admin])
      changeset = Ecto.Changeset.cast({%{}, %{role: type}}, %{role: "invalid"}, [:role])
      exception = Ecto.InvalidChangesetError.exception(action: :insert, changeset: changeset)

      Sentry.capture_exception(exception)

      [event] = Sentry.Test.pop_sentry_reports()
      assert [%{metadata: metadata}] = event.extra.changeset_errors.role
      assert metadata.type == inspect(type)

      assert {:ok, _json} =
               event
               |> Sentry.Client.render_event()
               |> Sentry.JSON.encode(Sentry.Config.json_library())
    end

    @tag :capture_log
    test "adds nested changeset errors while preserving the exception message" do
      content = String.duplicate("private-инструкции", 8192)

      changeset =
        InteractionSchema.changeset(
          %InteractionSchema{task_id: Ecto.UUID.generate()},
          %{
            id: Ecto.UUID.generate(),
            type: :discovered_project_rule,
            data: %{path: "AGENTS.md", content: content}
          }
        )

      exception = Ecto.InvalidChangesetError.exception(action: :insert, changeset: changeset)
      :logger.error(%{reason: {exception, []}})

      [event] = Sentry.Test.pop_sentry_reports()
      assert [%{message: message, metadata: metadata}] = event.extra.changeset_errors.data.content
      assert message == "should be at most %{count} byte(s)"
      assert metadata.count == 65_536
      [reported] = event.exception
      assert reported.value == Exception.message(exception)
    end

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

  describe "Sentry logger filtering" do
    test "drops ReqLLM streaming rate-limit errors" do
      event = %{
        level: :error,
        msg:
          {:string,
           "Finch streaming failed: %ReqLLM.Error.API.Request{reason: \"rate limited\", status: 429}"},
        meta: %{file: "lib/req_llm/streaming/finch_client.ex"}
      }

      assert FrontmanServer.Application.sentry_logger_filter(event, []) == :stop
    end

    test "drops ReqLLM streaming rate-limit errors with Logger file metadata" do
      event = %{
        level: :error,
        msg:
          {:string,
           "Finch streaming failed: %ReqLLM.Error.API.Request{reason: \"rate limited\", status: 429}"},
        meta: %{file: ~c"/app/lib/req_llm/streaming/finch_client.ex"}
      }

      assert FrontmanServer.Application.sentry_logger_filter(event, []) == :stop
    end

    test "keeps non-rate-limit ReqLLM streaming errors" do
      event = %{
        level: :error,
        msg:
          {:string,
           "Finch streaming failed: %ReqLLM.Error.API.Request{reason: \"server error\", status: 500}"},
        meta: %{file: "lib/req_llm/streaming/finch_client.ex"}
      }

      assert FrontmanServer.Application.sentry_logger_filter(event, []) == :ignore
    end
  end
end
