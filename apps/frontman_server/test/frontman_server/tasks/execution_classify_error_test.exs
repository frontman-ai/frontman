defmodule FrontmanServer.Tasks.ExecutionClassifyErrorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.ErrorClassifier
  alias FrontmanServer.Tasks.Execution.LLMError
  alias FrontmanServer.Tasks.StreamStallTimeout
  alias ReqLLM.Error.API.{Request, Stream}

  describe "classify_error/1" do
    test "LLMError passes through message, category, retryable" do
      err = %LLMError{message: "Rate limited", category: "rate_limit", retryable: true}

      assert %{message: "Rate limited", category: "rate_limit", retryable: true} =
               ErrorClassifier.classify_error(err)
    end

    test "ReqLLM request error 429 is classified as retryable rate limit" do
      err = Request.exception(status: 429, reason: "Too many requests")
      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "rate_limit"
      assert error_info.retryable == true
      assert String.contains?(error_info.message, "Rate limited")
    end

    test "OpenAI Codex usage limit 429 is classified as non-retryable quota" do
      reset_at = DateTime.utc_now(:second) |> DateTime.add(3600, :second)

      err =
        Request.exception(
          status: 429,
          reason: "The usage limit has been reached",
          response_body: %{
            "error" => %{
              "message" => "The usage limit has been reached",
              "type" => "usage_limit_reached",
              "resets_at" => DateTime.to_iso8601(reset_at)
            }
          }
        )

      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "quota"
      assert error_info.retryable == false
      assert error_info.retry_available_at == reset_at
      assert String.contains?(error_info.message, "quota")
    end

    test "Claude Code limits classify as quota and use structured reset data only" do
      reset_at = ~U[2030-10-21 07:28:00Z]

      for message <- [
            "You've hit your session limit · resets 3:45pm",
            "You've hit your weekly limit · resets Mon 12:00am",
            "You've hit your Opus limit · resets 3:45pm"
          ] do
        error_info =
          ErrorClassifier.classify_error(
            Request.exception(
              status: 429,
              reason: message,
              response_body: %{"error" => %{"message" => message}}
            )
          )

        assert %{category: "quota", retryable: false, retry_available_at: nil} = error_info
      end

      error_info =
        ErrorClassifier.classify_error(
          Request.exception(
            status: 429,
            response_body: %{
              "error" => %{"message" => "You've hit your session limit"},
              "rate_limits" => %{
                "five_hour" => %{
                  "used_percentage" => 100,
                  "resets_at" => DateTime.to_unix(reset_at)
                }
              }
            }
          )
        )

      assert %{category: "quota", retryable: false} = error_info
      assert error_info.retry_available_at == reset_at
    end

    test "OpenAI Codex usage limit 429 reads reset seconds from response body" do
      err =
        Request.exception(
          status: 429,
          reason: "The usage limit has been reached",
          response_body: %{
            "error" => %{
              "message" => "The usage limit has been reached",
              "type" => "usage_limit_reached",
              "resets_in_seconds" => 90
            }
          }
        )

      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "quota"
      assert error_info.retryable == false
      assert_retry_available_in(error_info, 90)
    end

    test "OpenAI Codex exhausted weekly quota header is classified as non-retryable quota" do
      reset_at = DateTime.utc_now(:second) |> DateTime.add(7200, :second)

      err =
        Request.exception(
          status: 429,
          reason: "Too many requests",
          headers: [
            {"x-codex-secondary-used-percent", "100"},
            {"x-codex-plan-type", "plus"},
            {"x-codex-secondary-reset-at", DateTime.to_iso8601(reset_at)}
          ]
        )

      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "quota"
      assert error_info.retryable == false
      assert error_info.retry_available_at == reset_at
      assert String.contains?(error_info.message, "quota")
    end

    test "OpenAI Codex exhausted quota header reads reset seconds" do
      err =
        Request.exception(
          status: 429,
          reason: "Too many requests",
          headers: [
            {"x-codex-secondary-used-percent", "100"},
            {"x-codex-secondary-reset-after-seconds", "120"}
          ]
        )

      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "quota"
      assert error_info.retryable == false
      assert_retry_available_in(error_info, 120)
    end

    test "generic retry-after seconds produces retry availability" do
      err =
        Request.exception(
          status: 429,
          reason: "Too many requests",
          headers: [{"retry-after", "45"}]
        )

      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "rate_limit"
      assert error_info.retryable == true
      assert_retry_available_in(error_info, 45)
    end

    test "generic retry-after at threshold remains retryable" do
      err =
        Request.exception(
          status: 429,
          reason: "Too many requests",
          headers: [{"retry-after", "60"}]
        )

      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "rate_limit"
      assert error_info.retryable == true
      assert_retry_available_in(error_info, 60)
    end

    test "generic retry-after above threshold is not auto-retryable" do
      err =
        Request.exception(
          status: 429,
          reason: "Too many requests",
          headers: [{"retry-after", "61"}]
        )

      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "rate_limit"
      assert error_info.retryable == false
      assert_retry_available_in(error_info, 61)
    end

    test "generic retry-after HTTP date produces retry availability" do
      err =
        Request.exception(
          status: 429,
          reason: "Too many requests",
          headers: [{"retry-after", "Wed, 21 Oct 2030 07:28:00 GMT"}]
        )

      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "rate_limit"
      assert error_info.retryable == false
      assert error_info.retry_available_at == ~U[2030-10-21 07:28:00Z]
    end

    test "malformed reset metadata does not crash" do
      err =
        Request.exception(
          status: 429,
          reason: "The usage limit has been reached",
          response_body: %{
            "error" => %{
              "type" => "usage_limit_reached",
              "resets_at" => "not a timestamp"
            }
          }
        )

      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "quota"
      assert error_info.retryable == false
      assert error_info.retry_available_at == nil
    end

    test "wrapped llm_error request error delegates to underlying classifier" do
      err = {:llm_error, Request.exception(status: 429, reason: "Too many requests")}
      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "rate_limit"
      assert error_info.retryable == true
      assert String.contains?(error_info.message, "Rate limited")
    end

    test "ReqLLM stream error with request cause 413 is classified as payload too large" do
      request_error =
        Request.exception(
          status: 413,
          reason: "image exceeds the maximum allowed size"
        )

      err = Stream.exception(reason: "Stream failed", cause: request_error)

      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "payload_too_large"
      assert error_info.retryable == false
      assert String.contains?(error_info.message, "Payload too large")
    end

    test "StreamStallTimeout.Error returns overload, retryable" do
      err = %StreamStallTimeout.Error{}
      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "overload"
      assert error_info.retryable == true
      assert String.length(error_info.message) > 0
    end

    test "wrapped StreamStallTimeout.Error returns overload, retryable" do
      err = {:exception, %StreamStallTimeout.Error{timeout_ms: 60_000}}
      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "overload"
      assert error_info.retryable == true
      assert String.contains?(error_info.message, "stopped responding")
    end

    test ":genserver_call_timeout returns overload, retryable" do
      error_info = ErrorClassifier.classify_error(:genserver_call_timeout)

      assert error_info.category == "overload"
      assert error_info.retryable == true
      assert String.length(error_info.message) > 0
    end

    test ":stream_timeout returns overload, retryable" do
      error_info = ErrorClassifier.classify_error(:stream_timeout)

      assert error_info.category == "overload"
      assert error_info.retryable == true
      assert String.length(error_info.message) > 0
    end

    test ":output_truncated returns output_truncated, not retryable" do
      error_info = ErrorClassifier.classify_error(:output_truncated)

      assert error_info.category == "output_truncated"
      assert error_info.retryable == false
      assert String.length(error_info.message) > 0
    end

    test "{:exit, reason} returns unknown, not retryable" do
      error_info = ErrorClassifier.classify_error({:exit, :some_reason})

      assert error_info.category == "unknown"
      assert error_info.retryable == false
      assert String.contains?(error_info.message, "some_reason")
    end

    test "generic exception returns unknown, not retryable" do
      err = %RuntimeError{message: "something bad"}
      error_info = ErrorClassifier.classify_error(err)

      assert error_info.category == "unknown"
      assert error_info.retryable == false
      assert String.contains?(error_info.message, "something bad")
    end

    test "binary reason returns as-is with unknown, not retryable" do
      assert %{message: "custom error", category: "unknown", retryable: false} =
               ErrorClassifier.classify_error("custom error")
    end

    test "unknown atom returns inspect string with unknown, not retryable" do
      error_info = ErrorClassifier.classify_error(:some_weird_atom)

      assert error_info.category == "unknown"
      assert error_info.retryable == false
      assert String.contains?(error_info.message, "some_weird_atom")
    end
  end

  defp assert_retry_available_in(error_info, expected_seconds) do
    seconds_left = DateTime.diff(error_info.retry_available_at, DateTime.utc_now(), :second)

    assert seconds_left >= expected_seconds - 2
    assert seconds_left <= expected_seconds + 2
  end
end
