defmodule FrontmanServer.Tasks.ExecutionClassifyErrorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.ErrorClassifier
  alias FrontmanServer.Tasks.Execution.LLMError
  alias FrontmanServer.Tasks.StreamStallTimeout
  alias ReqLLM.Error.API.{Request, Stream}

  describe "classify_error/1" do
    test "LLMError passes through message, category, retryable" do
      err = %LLMError{message: "Rate limited", category: "rate_limit", retryable: true}
      assert_info(err, "rate_limit", true, "Rate limited")
    end

    test "request errors map provider statuses to categories" do
      cases = [
        {429, "Too many requests", "rate_limit", true, "Rate limited"},
        {401, nil, "auth", false, "Authentication failed"},
        {403, nil, "auth", false, "Authentication failed"},
        {400, "bad", "unknown", false, "Bad request"},
        {402, nil, "billing", false, "Payment required"},
        {413, nil, "payload_too_large", false, "Payload too large"},
        {500, nil, "overload", true, "Provider error"},
        {418, "teapot", "unknown", false, "LLM error"}
      ]

      for {status, reason, category, retryable, message} <- cases do
        assert_info(
          Request.exception(status: status, reason: reason),
          category,
          retryable,
          message
        )
      end
    end

    test "quota signals are non-retryable and expose reset metadata" do
      reset_at = ~U[2030-10-21 07:28:00Z]

      for message <- [
            "You've hit your session limit · resets 3:45pm",
            "You've hit your weekly limit · resets Mon 12:00am",
            "You've hit your Opus limit · resets 3:45pm"
          ] do
        error_info =
          classify_request(response_body: %{"error" => %{"message" => message}})

        assert %{category: "quota", retryable: false, retry_available_at: nil} = error_info
      end

      assert classify_request(
               response_body: %{
                 "error" => %{
                   "message" => "The usage limit has been reached",
                   "type" => "usage_limit_reached",
                   "resets_at" => DateTime.to_iso8601(reset_at)
                 }
               }
             ).retry_available_at == reset_at

      assert_retry_available_in(
        classify_request(
          response_body: %{
            "error" => %{"type" => "usage_limit_reached", "resets_in_seconds" => 90}
          }
        ),
        90
      )

      assert classify_request(
               response_body: %{
                 "error" => %{"message" => "You've hit your session limit"},
                 "rate_limits" => %{
                   "five_hour" => %{
                     "used_percentage" => 100,
                     "resets_at" => DateTime.to_unix(reset_at)
                   }
                 }
               }
             ).retry_available_at == reset_at

      assert classify_request(
               headers: [
                 {"x-codex-secondary-used-percent", "100"},
                 {"x-codex-secondary-reset-at", DateTime.to_iso8601(reset_at)}
               ]
             ).retry_available_at == reset_at

      assert_retry_available_in(
        classify_request(
          headers: [
            {"x-codex-secondary-used-percent", "100"},
            {"x-codex-secondary-reset-after-seconds", "120"}
          ]
        ),
        120
      )
    end

    test "retry-after controls automatic retry eligibility" do
      for {seconds, retryable} <- [{45, true}, {60, true}, {61, false}] do
        error_info = classify_request(headers: [{"retry-after", Integer.to_string(seconds)}])
        assert %{category: "rate_limit", retryable: ^retryable} = error_info
        assert_retry_available_in(error_info, seconds)
      end

      error_info = classify_request(headers: [{"retry-after", "Wed, 21 Oct 2030 07:28:00 GMT"}])

      assert %{category: "rate_limit", retryable: false} = error_info
      assert error_info.retry_available_at == ~U[2030-10-21 07:28:00Z]
    end

    test "malformed reset metadata does not crash" do
      error_info =
        classify_request(
          response_body: %{"error" => %{"type" => "usage_limit_reached", "resets_at" => "bad"}}
        )

      assert %{category: "quota", retryable: false, retry_available_at: nil} = error_info
    end

    test "wrapped and stream errors delegate to underlying classifiers" do
      assert_info(
        {:llm_error, Request.exception(status: 429)},
        "rate_limit",
        true,
        "Rate limited"
      )

      request_error = Request.exception(status: 413, reason: "image too large")

      assert_info(
        Stream.exception(reason: "Stream failed", cause: request_error),
        "payload_too_large",
        false,
        "Payload too large"
      )
    end

    test "timeouts and generic reasons keep expected categories" do
      cases = [
        {%StreamStallTimeout.Error{}, "overload", true, "stopped responding"},
        {{:exception, %StreamStallTimeout.Error{timeout_ms: 60_000}}, "overload", true,
         "stopped responding"},
        {:genserver_call_timeout, "overload", true, "request to the AI provider timed out"},
        {:stream_timeout, "overload", true, "request to the AI provider timed out"},
        {:output_truncated, "output_truncated", false, "response was too long"},
        {{:exit, :some_reason}, "unknown", false, "some_reason"},
        {%RuntimeError{message: "something bad"}, "unknown", false, "something bad"},
        {"custom error", "unknown", false, "custom error"},
        {:some_weird_atom, "unknown", false, "some_weird_atom"}
      ]

      for {reason, category, retryable, message} <- cases do
        assert_info(reason, category, retryable, message)
      end
    end
  end

  defp classify_request(opts) do
    opts
    |> Keyword.put_new(:status, 429)
    |> Request.exception()
    |> ErrorClassifier.classify_error()
  end

  defp assert_info(reason, category, retryable, message) do
    error_info = ErrorClassifier.classify_error(reason)

    assert error_info.category == category
    assert error_info.retryable == retryable
    assert String.contains?(error_info.message, message)
  end

  defp assert_retry_available_in(error_info, expected_seconds) do
    seconds_left = DateTime.diff(error_info.retry_available_at, DateTime.utc_now(), :second)

    assert seconds_left >= expected_seconds - 2
    assert seconds_left <= expected_seconds + 2
  end
end
