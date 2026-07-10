defmodule FrontmanServer.Tasks.ExecutionClassifyTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.ErrorClassifier
  alias FrontmanServer.Tasks.Execution.LLMError
  alias FrontmanServer.Tasks.StreamStallTimeout

  describe "classify_error/1" do
    test "LLMError preserves category and retryable" do
      err = %LLMError{message: "Rate limited", category: "rate_limit", retryable: true}

      assert %{message: "Rate limited", category: "rate_limit", retryable: true} =
               ErrorClassifier.classify_error(err)
    end

    test "LLMError auth is not retryable" do
      err = %LLMError{message: "Auth failed", category: "auth", retryable: false}

      assert %{message: "Auth failed", category: "auth", retryable: false} =
               ErrorClassifier.classify_error(err)
    end

    test "StreamStallTimeout is retryable with overload category" do
      err = %StreamStallTimeout.Error{timeout_ms: 30_000}
      error_info = ErrorClassifier.classify_error(err)

      assert error_info.retryable == true
      assert error_info.category == "overload"
      assert String.contains?(error_info.message, "stopped responding")
    end

    test ":genserver_call_timeout is retryable with overload category" do
      error_info = ErrorClassifier.classify_error(:genserver_call_timeout)

      assert error_info.retryable == true
      assert error_info.category == "overload"
    end

    test ":output_truncated is not retryable" do
      error_info = ErrorClassifier.classify_error(:output_truncated)

      assert error_info.retryable == false
      assert error_info.category == "output_truncated"
    end

    test "unknown reason is not retryable with unknown category" do
      error_info = ErrorClassifier.classify_error(:some_unknown_atom)

      assert error_info.retryable == false
      assert error_info.category == "unknown"
    end
  end
end
