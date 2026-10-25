defmodule FrontmanServer.Tasks.ExecutionClassifyErrorTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.ErrorClassifier
  alias ReqLLM.Error.API.Request

  describe "classify_error/1" do
    test "model discovery outages give retryable guidance" do
      assert {message, "overload", true} =
               ErrorClassifier.classify_error(:model_discovery_failed)

      assert message =~ "model availability"
    end

    test "structured model_not_found failures return safe guidance through stream wrappers" do
      reason =
        "The 'gpt-6-astra' model is not supported when using Codex with a ChatGPT account."

      body = %{
        "code" => "model_not_found",
        "message" => reason,
        "type" => "invalid_request_error"
      }

      for opts <- [
            [provider_code: "model_not_found", response_body: body, reason: reason],
            [provider_code: "model_not_found", reason: "private-input"],
            [response_body: body, reason: "private-input"],
            [response_body: %{"error" => body}, reason: "private-input"],
            [response_body: %{"detail" => reason}, reason: "private-input"]
          ] do
        request = Request.exception([status: 400] ++ opts)
        stream = ReqLLM.Error.API.Stream.exception(cause: request, reason: "private-input")

        for failure <- [request, stream, {:llm_error, stream}, {:exception, stream}] do
          assert ErrorClassifier.classify_error(failure) ==
                   {"This model is unavailable for your connection. Select another model and send a new message.",
                    "unknown", false}
        end
      end
    end

    test "request failures give safe guidance without exposing provider data" do
      for {status, category, message} <- [
            {400, "unknown", "Bad request — the provider rejected the request."},
            {401, "auth",
             "Authentication failed (HTTP 401). In Settings, disconnect and reconnect your provider account. To use an API key instead, disconnect the account first. If you already use an API key, replace it."},
            {403, "auth",
             "Authentication failed (HTTP 403). In Settings, disconnect and reconnect your provider account. To use an API key instead, disconnect the account first. If you already use an API key, replace it."}
          ],
          body <- [
            %{"detail" => "The 'private-input' field is invalid"},
            %{"detail" => ["private-input"]},
            %{"code" => "invalid_request_error", "message" => "private-input"},
            %{"error" => %{"code" => "invalid_request_error", "message" => "private-input"}},
            %{"error" => %{"message" => "private-input"}},
            %{"error" => %{"code" => "token_invalidated", "message" => "private-input"}},
            nil
          ] do
        assert {^message, ^category, false} =
                 classify_request(status: status, reason: "private-input", response_body: body)
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
