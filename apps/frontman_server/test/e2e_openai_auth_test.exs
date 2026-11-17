# This standalone suite does not load test_helper.exs or start the application.
ExUnit.start()
Code.require_file("../priv/scripts/e2e_openai_auth.exs", __DIR__)

defmodule FrontmanServer.E2EOpenAIAuthTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.E2EOpenAIAuth, as: Auth
  alias ReqLLM.Providers.OpenAICodex
  alias ReqLLM.Streaming.Failure

  setup_all do
    if is_nil(Process.whereis(ReqLLM.Supervisor)), do: ReqLLM.Providers.initialize()
    :ok
  end

  test "force refresh overrides a future expiration without changing read/conditional decisions" do
    now = ~U[2026-01-01 00:00:00Z]
    future = {:ok, DateTime.add(now, 86_400)}

    assert Auth.refresh_needed?("force_refresh", future, now, 1800)
    refute Auth.refresh_needed?("read", future, now, 1800)
    refute Auth.refresh_needed?("refresh_if_needed", future, now, 1800)
    assert Auth.refresh_needed?("refresh_if_needed", {:ok, DateTime.add(now, 1800)}, now, 1800)
    assert Auth.refresh_needed?("refresh_if_needed", {:ok, DateTime.add(now, -1)}, now, 1800)
    assert Auth.refresh_needed?("refresh_if_needed", {:error, :missing_exp}, now, 1800)
  end

  test "mode validation rejects typos and unexpected values without echoing input" do
    for mode <- ["read", "refresh_if_needed", "force_refresh"] do
      assert Auth.validate_mode!(mode) == mode
    end

    for mode <- ["force", "true", "", "FORCE_REFRESH", "credential-bearing-input"] do
      error = assert_raise ArgumentError, fn -> Auth.validate_mode!(mode) end

      assert Exception.message(error) ==
               "E2E_OPENAI_TOKEN_MODE must be read, refresh_if_needed, or force_refresh"
    end
  end

  test "real ReqLLM HTTP failure normalization retains explicit authentication rejection" do
    for status <- [401, 403] do
      error = Failure.api_error(status, ~s({"error":{"code":"token_revoked"}}), [])
      assert Auth.classify(error) == :auth_rejected

      wrapped = ReqLLM.Error.API.Stream.exception(reason: "stream failed", cause: error)
      assert Auth.classify(wrapped) == :auth_rejected
    end

    for status <- [400, 403, 429, 500, 502, 503] do
      error = Failure.api_error(status, ~s({"error":{"code":"permission_denied"}}), [])
      assert Auth.classify(error) == :other
    end

    for status <- [429, 500] do
      error = Failure.api_error(status, ~s({"error":{"code":"token_revoked"}}), [])
      assert Auth.classify(error) == :other
      cause = Failure.api_error(401, nil, [])
      assert Auth.classify(%{error | cause: cause}) == :other
    end

    assert Auth.classify(Req.TransportError.exception(reason: :timeout)) == :other
    assert Auth.classify(Req.TransportError.exception(reason: :econnrefused)) == :other
  end

  test "real Codex SSE decoder distinguishes revoked auth from rate limits and server errors" do
    {:ok, model} = ReqLLM.model(Auth.model_spec())

    for {code, expected} <- [
          {"token_revoked", :auth_rejected},
          {"rate_limit_exceeded", :other},
          {"server_error", :other}
        ] do
      chunks =
        OpenAICodex.decode_stream_event(
          %{event: "error", data: %{"type" => "error", "error" => %{"code" => code}}},
          model
        )

      assert Enum.any?(chunks, &(&1.metadata[:finish_reason] == :error))
      assert Enum.map(chunks, &Auth.classify/1) |> Enum.member?(expected)
    end
  end

  test "preflight model uses E2E's first Codex catalog entry and real OAuth transport builder" do
    %{models: [entry | _]} =
      Application.fetch_env!(:frontman_server, :providers) |> Keyword.fetch!(:openai_codex)

    assert Auth.model_spec() == "openai_codex:#{elem(entry, 1)}"
    {:ok, model} = ReqLLM.model(Auth.model_spec())
    assert model.provider == :openai_codex
    {:ok, context} = ReqLLM.Context.normalize("Reply only OK.")

    {:ok, request} =
      OpenAICodex.attach_stream(
        model,
        context,
        [
          auth_mode: :oauth,
          access_token: "test-access-token",
          chatgpt_account_id: "test-account"
        ],
        nil
      )

    assert {"authorization", "Bearer test-access-token"} in request.headers
    assert {"chatgpt-account-id", "test-account"} in request.headers
    assert Jason.decode!(request.body)["stream"]
  end

  test "refresh errors give recovery instructions without provider payloads" do
    for status <- [400, 401, 403] do
      message = Auth.refresh_error({:token_refresh_failed, status, "credential-bearing-input"})
      assert message =~ "Reauthorization required"
      refute message =~ "credential-bearing-input"
    end

    message = Auth.refresh_error({:request_failed, "credential-bearing-input"})
    refute message =~ "credential-bearing-input"
    refute message =~ "Reauthorization required"
  end
end
