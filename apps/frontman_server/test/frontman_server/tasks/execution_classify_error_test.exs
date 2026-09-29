defmodule FrontmanServer.Tasks.ExecutionClassifyErrorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.ErrorClassifier
  alias ReqLLM.Error.API.Request

  describe "classify_error/1" do
    test "request failures give safe guidance without exposing provider data" do
      for {status, category, message} <- [
            {400, "unknown", "Bad request — the provider rejected the request."},
            {401, "auth",
             "Authentication failed (HTTP 401). Reconnect your provider account by signing in again, or replace your API key in Settings."},
            {403, "auth",
             "Authentication failed (HTTP 403). Reconnect your provider account by signing in again, or replace your API key in Settings."}
          ],
          body <- [
            %{"detail" => "The 'private-input' field is invalid"},
            %{"detail" => ["private-input"]},
            %{"error" => %{"message" => "private-input"}},
            %{"error" => %{"code" => "token_invalidated", "message" => "private-input"}},
            nil
          ] do
        assert {^message, ^category, false} =
                 classify_request(status: status, reason: "private-input", response_body: body)
      end
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
