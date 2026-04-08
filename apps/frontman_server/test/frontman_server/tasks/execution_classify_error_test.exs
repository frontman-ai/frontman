defmodule FrontmanServer.Tasks.ExecutionClassifyErrorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.LLMError
  alias FrontmanServer.Tasks.ExecutionEvent
  alias FrontmanServer.Tasks.StreamStallTimeout

  describe "classify_error/1" do
    test "LLMError passes through message, category, retryable" do
      err = %LLMError{message: "Rate limited", category: "rate_limit", retryable: true}
      assert {"Rate limited", "rate_limit", true} = ExecutionEvent.classify_error(err)
    end

    test "StreamStallTimeout.Error returns overload, retryable" do
      err = %StreamStallTimeout.Error{}
      {msg, "overload", true} = ExecutionEvent.classify_error(err)
      assert is_binary(msg) and String.length(msg) > 0
    end

    test ":genserver_call_timeout returns overload, retryable" do
      {msg, "overload", true} = ExecutionEvent.classify_error(:genserver_call_timeout)
      assert is_binary(msg) and String.length(msg) > 0
    end

    test ":stream_timeout returns overload, retryable" do
      {msg, "overload", true} = ExecutionEvent.classify_error(:stream_timeout)
      assert is_binary(msg) and String.length(msg) > 0
    end

    test ":output_truncated returns output_truncated, not retryable" do
      {msg, "output_truncated", false} = ExecutionEvent.classify_error(:output_truncated)
      assert is_binary(msg) and String.length(msg) > 0
    end

    test "{:exit, reason} returns unknown, not retryable" do
      {msg, "unknown", false} = ExecutionEvent.classify_error({:exit, :some_reason})
      assert String.contains?(msg, "some_reason")
    end

    test "generic exception returns unknown, not retryable" do
      err = %RuntimeError{message: "something bad"}
      {msg, "unknown", false} = ExecutionEvent.classify_error(err)
      assert String.contains?(msg, "something bad")
    end

    test "binary reason returns as-is with unknown, not retryable" do
      {"custom error", "unknown", false} = ExecutionEvent.classify_error("custom error")
    end

    test "unknown atom returns inspect string with unknown, not retryable" do
      {msg, "unknown", false} = ExecutionEvent.classify_error(:some_weird_atom)
      assert String.contains?(msg, "some_weird_atom")
    end
  end
end
