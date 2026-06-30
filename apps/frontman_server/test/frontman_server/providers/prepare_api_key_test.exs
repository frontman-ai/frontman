defmodule FrontmanServer.Providers.PrepareApiKeyTest do
  @moduledoc """
  Integration tests for the full `Providers.prepare_llm_args/3` resolution chain.

  Tests the priority order: OAuth > user key.
  This is the primary entry point for all LLM key resolution in the system.
  """
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias ReqLLM.Context
  alias ReqLLM.Providers.Anthropic

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  setup do
    user = user_fixture()
    scope = %Scope{user: user}
    {:ok, scope: scope}
  end

  describe "prepare_llm_args/3 resolution priority" do
    test "resolves OAuth token as highest priority for anthropic", %{scope: scope} do
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(scope, "anthropic", "oauth_access", "refresh", expires_at)

      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")

      {:ok, {model, llm_opts}} =
        Providers.prepare_llm_args(scope, "anthropic:claude-sonnet-4-5")

      assert model == "anthropic:claude-sonnet-4-5"
      assert llm_opts[:access_token] == "oauth_access"
      assert llm_opts[:auth_mode] == :oauth
      assert llm_opts[:with_claude_subscription] == true
      assert llm_opts[:anthropic_prompt_cache] == true
      assert llm_opts[:anthropic_cache_messages] == -1
    end

    test "falls back to user key when no OAuth token", %{scope: scope} do
      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")

      {:ok, {_model, llm_opts}} =
        Providers.prepare_llm_args(scope, "anthropic:claude-sonnet-4-5")

      assert llm_opts[:api_key] == "user_key_456"
      assert llm_opts[:anthropic_prompt_cache] == true
      assert llm_opts[:anthropic_cache_messages] == -1
    end

    test "resolved Anthropic opts mark the last message for prompt caching", %{scope: scope} do
      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")

      {:ok, {model, llm_opts}} =
        Providers.prepare_llm_args(scope, "anthropic:claude-sonnet-4-5")

      context =
        Context.new([
          Context.system("system prompt"),
          Context.user("first user message"),
          Context.assistant("assistant reply"),
          Context.user("latest user message")
        ])

      {:ok, request} = Anthropic.prepare_request(:chat, model, context, llm_opts)
      encoded_request = Anthropic.encode_body(request)
      body = encoded_request.options[:json]

      last_message = List.last(body[:messages])
      [last_block] = last_message[:content]

      assert last_message[:role] == "user"
      assert last_block[:text] == "latest user message"
      assert last_block[:cache_control] == %{type: "ephemeral"}
    end

    test "returns :no_api_key when no key source is available", %{scope: scope} do
      assert {:error, :no_api_key} =
               Providers.prepare_llm_args(scope, "anthropic:claude-sonnet-4-5")
    end

    test "refreshes expired Anthropic OAuth token before resolving LLM args", %{scope: scope} do
      expired_at = DateTime.add(DateTime.utc_now(), -60, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(scope, "anthropic", "expired_access", "refresh", expired_at)

      expect_anthropic_refresh_success()

      {:ok, {_model, llm_opts}} =
        Providers.prepare_llm_args(scope, "anthropic:claude-sonnet-4-5")

      assert llm_opts[:access_token] == "fresh_access"
      assert llm_opts[:auth_mode] == :oauth
    end

    test "invalid Anthropic refresh falls back to API key and deletes token", %{scope: scope} do
      expired_at = DateTime.add(DateTime.utc_now(), -60, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(scope, "anthropic", "expired_access", "refresh", expired_at)

      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")

      expect_anthropic_refresh_permanent_failure()

      {:ok, {_model, llm_opts}} =
        Providers.prepare_llm_args(scope, "anthropic:claude-sonnet-4-5")

      assert llm_opts[:api_key] == "user_key_456"
      assert is_nil(Providers.get_oauth_token(scope, "anthropic"))
    end

    test "transient Anthropic refresh failure keeps token and can recover", %{scope: scope} do
      expired_at = DateTime.add(DateTime.utc_now(), -60, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(scope, "anthropic", "expired_access", "refresh", expired_at)

      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")
      expect_anthropic_refresh_transient_failure()

      {:ok, {_model, llm_opts}} =
        Providers.prepare_llm_args(scope, "anthropic:claude-sonnet-4-5")

      assert llm_opts[:api_key] == "user_key_456"
      refute is_nil(Providers.get_oauth_token(scope, "anthropic"))

      expect_anthropic_refresh_success()

      {:ok, {_model, llm_opts}} =
        Providers.prepare_llm_args(scope, "anthropic:claude-sonnet-4-5")

      assert llm_opts[:access_token] == "fresh_access"
    end

    test "returns :missing_model when no model is provided", %{scope: scope} do
      assert {:error, :missing_model} = Providers.prepare_llm_args(scope, nil)
    end

    test "openrouter user key resolves correctly", %{scope: scope} do
      {:ok, _} = Providers.upsert_api_key(scope, "openrouter", "sk-or-user-test")

      {:ok, {model, llm_opts}} = Providers.prepare_llm_args(scope, "openrouter:openai/gpt-5.5")

      assert model == "openrouter:openai/gpt-5.5"
      assert llm_opts[:api_key] == "sk-or-user-test"
    end

    test "openai codex oauth resolves direct ReqLLM args", %{scope: scope} do
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _} = upsert_openai_oauth_token(scope, expires_at)

      {:ok, {model, llm_opts}} =
        Providers.prepare_llm_args(scope, "openai_codex:gpt-5.3-codex", max_tokens: 16_384)

      assert model == "openai_codex:gpt-5.3-codex"
      assert llm_opts[:access_token] == "openai_access"
      assert llm_opts[:auth_mode] == :oauth
      assert llm_opts[:chatgpt_account_id] == "acc-789"
      assert llm_opts[:max_tokens] == 16_384
    end

    test "refreshes expired OpenAI OAuth token before resolving LLM args", %{scope: scope} do
      expired_at = DateTime.add(DateTime.utc_now(), -60, :second)
      {:ok, _} = upsert_openai_oauth_token(scope, expired_at)
      expect_openai_refresh_success()

      {:ok, {_model, llm_opts}} =
        Providers.prepare_llm_args(scope, "openai_codex:gpt-5.3-codex")

      assert llm_opts[:access_token] == "fresh_openai_access"
      assert llm_opts[:auth_mode] == :oauth
      assert llm_opts[:chatgpt_account_id] == "acc-789"
    end

    test "permanent OpenAI refresh failure deletes expired OAuth token", %{scope: scope} do
      expired_at = DateTime.add(DateTime.utc_now(), -60, :second)
      {:ok, _} = upsert_openai_oauth_token(scope, expired_at)
      expect_openai_refresh_permanent_failure()

      assert {:error, :no_api_key} =
               Providers.prepare_llm_args(scope, "openai_codex:gpt-5.3-codex")

      assert is_nil(Providers.get_oauth_token(scope, "openai_codex"))
    end

    test "openai codex oauth without account id is invalid", %{scope: scope} do
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(
          scope,
          "openai_codex",
          "openai_access",
          "refresh",
          expires_at
        )

      assert {:error, :invalid_oauth_token} =
               Providers.prepare_llm_args(scope, "openai_codex:gpt-5.5")
    end
  end

  describe "OAuth availability refresh" do
    test "model config refreshes expired Anthropic token", %{scope: scope} do
      expired_at = DateTime.add(DateTime.utc_now(), -60, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(scope, "anthropic", "expired_access", "refresh", expired_at)

      expect_anthropic_refresh_success()

      config = Providers.model_config_data(scope)

      assert Enum.any?(config.groups, &(&1.id == "anthropic"))
    end

    test "connection status refreshes expired OpenAI token", %{scope: scope} do
      expired_at = DateTime.add(DateTime.utc_now(), -60, :second)
      {:ok, _} = upsert_openai_oauth_token(scope, expired_at)
      expect_openai_refresh_success()

      assert %{
               connected: true,
               expired: false,
               expires_at: expires_at
             } = Providers.oauth_connection_status(scope, "openai_codex")

      assert {:ok, refreshed_expires_at, _offset} = DateTime.from_iso8601(expires_at)
      assert DateTime.compare(refreshed_expires_at, DateTime.utc_now()) == :gt
    end
  end

  describe "model provider names" do
    test "openai_codex is the provider id" do
      assert Providers.model_provider_name("openai_codex:gpt-5.5") == "openai_codex"
      assert Providers.model_provider_name(%{provider: :openai_codex}) == "openai_codex"
      assert Providers.model_llm_vendor_name("openai_codex:gpt-5.5") == "openai_codex"
      assert Providers.model_llm_vendor_name(%{provider: :openai_codex}) == "openai_codex"

      assert Providers.max_image_dimension(Providers.model_provider_name("openai_codex:gpt-5.5")) ==
               nil
    end
  end

  defp expect_anthropic_refresh_success do
    Req.Test.expect(:anthropic_oauth, fn conn ->
      Req.Test.json(conn, %{
        "access_token" => "fresh_access",
        "refresh_token" => "fresh_refresh",
        "expires_in" => 3600
      })
    end)
  end

  defp expect_anthropic_refresh_permanent_failure do
    Req.Test.expect(:anthropic_oauth, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{"error" => "invalid_grant"})
    end)
  end

  defp expect_anthropic_refresh_transient_failure do
    Req.Test.expect(:anthropic_oauth, fn conn ->
      conn
      |> Plug.Conn.put_status(500)
      |> Req.Test.json(%{"error" => "server_error"})
    end)
  end

  defp upsert_openai_oauth_token(scope, expires_at) do
    Providers.upsert_oauth_token(
      scope,
      "openai_codex",
      "openai_access",
      "refresh",
      expires_at,
      %{"account_id" => "acc-789"}
    )
  end

  defp expect_openai_refresh_success do
    Req.Test.expect(:openai_oauth, fn conn ->
      Req.Test.json(conn, %{
        "access_token" => "fresh_openai_access",
        "refresh_token" => "fresh_openai_refresh",
        "expires_in" => 3600
      })
    end)
  end

  defp expect_openai_refresh_permanent_failure do
    Req.Test.expect(:openai_oauth, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(%{"error" => "invalid_grant"})
    end)
  end
end
