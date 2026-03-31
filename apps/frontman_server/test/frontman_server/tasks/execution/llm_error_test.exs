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
end
