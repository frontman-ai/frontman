defmodule FrontmanServer.Tasks.Execution.LLMErrorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.LLMError

  test "is a valid exception" do
    err = %LLMError{message: "Rate limited", category: "rate_limit", retryable: true}
    assert Exception.message(err) == "Rate limited"
  end

  test "has required fields" do
    err = %LLMError{message: "Auth failed", category: "auth", retryable: false}
    assert err.category == "auth"
    assert err.retryable == false
  end

  test "can be raised and caught with raise/rescue" do
    err =
      try do
        raise LLMError, message: "Rate limited", category: "rate_limit", retryable: true
      rescue
        e in LLMError -> e
      end

    assert err.message == "Rate limited"
    assert err.category == "rate_limit"
    assert err.retryable == true
  end

  describe "classify_llm_error via LLMClient stream" do
    test "LLMError can be raised with raise keyword" do
      error =
        assert_raise FrontmanServer.Tasks.Execution.LLMError, fn ->
          raise FrontmanServer.Tasks.Execution.LLMError,
            message: "Auth failed",
            category: "auth",
            retryable: false
        end

      assert error.category == "auth"
      assert error.retryable == false
    end
  end
end
