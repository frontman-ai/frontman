defmodule FrontmanServer.Tasks.ExecutionClassifyErrorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.ErrorClassifier
  alias ReqLLM.Error.API.Request

  describe "classify_error/1" do
    test "unrelated or malformed 400 bodies stay generic without exposing provider data" do
      for body <- [
            %{"detail" => "The 'private-input' field is invalid"},
            %{"detail" => ["private-input"]},
            %{"error" => %{"message" => "private-input"}},
            nil
          ] do
        assert {"Bad request — the provider rejected the request.", "unknown", false} =
                 classify_request(status: 400, reason: "private-input", response_body: body)
      end
    end

    test "402 explains provider billing without exposing provider data" do
      assert {message, "billing", false} =
               classify_request(status: 402, reason: "private-input")

      assert message =~ "AI provider"
      assert message =~ "separate from your Frontman subscription"
      refute message =~ "private-input"
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
