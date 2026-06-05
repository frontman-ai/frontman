defmodule FrontmanServer.Tasks.ExecutionClassifyTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.ErrorClassifier
  alias FrontmanServer.Tasks.Execution.LLMError
  alias FrontmanServer.Tasks.StreamStallTimeout

  describe "classify_error/1" do
    test "LLMError preserves category and retryable" do
      err = %LLMError{message: "Rate limited", category: "rate_limit", retryable: true}
      assert {msg, "rate_limit", true} = ErrorClassifier.classify_error(err)
      assert msg == "Rate limited"
    end

    test "LLMError auth is not retryable" do
      err = %LLMError{message: "Auth failed", category: "auth", retryable: false}
      assert {"Auth failed", "auth", false} = ErrorClassifier.classify_error(err)
    end

    test "StreamStallTimeout is retryable with overload category" do
      err = %StreamStallTimeout.Error{timeout_ms: 30_000}
      {msg, category, retryable} = ErrorClassifier.classify_error(err)
      assert retryable == true
      assert category == "overload"
      assert String.contains?(msg, "stopped responding")
    end

    test ":genserver_call_timeout is retryable with overload category" do
      {_msg, category, retryable} = ErrorClassifier.classify_error(:genserver_call_timeout)
      assert retryable == true
      assert category == "overload"
    end

    test ":output_truncated is not retryable" do
      {_msg, category, retryable} = ErrorClassifier.classify_error(:output_truncated)
      assert retryable == false
      assert category == "output_truncated"
    end

    test "unknown reason is not retryable with unknown category" do
      {_msg, category, retryable} = ErrorClassifier.classify_error(:some_unknown_atom)
      assert retryable == false
      assert category == "unknown"
    end
  end
end
