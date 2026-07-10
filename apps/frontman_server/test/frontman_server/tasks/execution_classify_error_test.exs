defmodule FrontmanServer.Tasks.ExecutionClassifyErrorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.ErrorClassifier
  alias FrontmanServer.Tasks.Execution.LLMError
  alias ReqLLM.Error.API.Request

  describe "classify_error/1" do
    test "LLMError passes through message, category, retryable" do
      err = %LLMError{message: "Rate limited", category: "rate_limit", retryable: true}
      assert {"Rate limited", "rate_limit", true} = ErrorClassifier.classify_error(err)
    end

    test "plain 429 remains retryable rate limit" do
      assert {msg, "rate_limit", true} = classify_request(reason: "Too many requests")
      assert String.contains?(msg, "Rate limited")
    end

    test "quota-like 429s are non-retryable quota" do
      for error <- [
            %{"type" => "usage_limit_reached"},
            %{"code" => "insufficient_quota"},
            %{"message" => "The usage limit has been reached"}
          ] do
        assert {_, "quota", false} = classify_request(response_body: %{"error" => error})
      end

      assert {_, "quota", false} =
               classify_request(headers: [{"x-codex-secondary-used-percent", "100"}])
    end

    test "wrapped request errors delegate to request classifier" do
      assert {_, "quota", false} =
               ErrorClassifier.classify_error(
                 {:llm_error,
                  Request.exception(
                    status: 429,
                    response_body: %{"error" => %{"type" => "usage_limit_reached"}}
                  )}
               )
    end
  end

  defp classify_request(opts) do
    opts
    |> Keyword.put_new(:status, 429)
    |> Request.exception()
    |> ErrorClassifier.classify_error()
  end
end
