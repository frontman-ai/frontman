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
    end

    test "falls back to user key when no OAuth token", %{scope: scope} do
      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")

      {:ok, {_model, llm_opts}} =
        Providers.prepare_llm_args(scope, "anthropic:claude-sonnet-4-5")

      assert llm_opts[:api_key] == "user_key_456"
    end

    test "returns :no_api_key when no key source is available", %{scope: scope} do
      assert {:error, :no_api_key} =
               Providers.prepare_llm_args(scope, "anthropic:claude-sonnet-4-5")
    end

    test "openrouter user key resolves correctly", %{scope: scope} do
      {:ok, _} = Providers.upsert_api_key(scope, "openrouter", "sk-or-user-test")

      {:ok, {model, llm_opts}} = Providers.prepare_llm_args(scope, "openrouter:openai/gpt-5.5")

      assert model == "openrouter:openai/gpt-5.5"
      assert llm_opts[:api_key] == "sk-or-user-test"
    end

    test "openai codex oauth resolves direct ReqLLM args", %{scope: scope} do
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(
          scope,
          "openai_codex",
          "openai_access",
          "refresh",
          expires_at,
          %{"account_id" => "acc-789"}
        )

      {:ok, {model, llm_opts}} =
        Providers.prepare_llm_args(scope, "openai_codex:gpt-5.3-codex", max_tokens: 16_384)

      assert model == "openai_codex:gpt-5.3-codex"
      assert llm_opts[:access_token] == "openai_access"
      assert llm_opts[:auth_mode] == :oauth
      assert llm_opts[:chatgpt_account_id] == "acc-789"
      assert llm_opts[:max_tokens] == 16_384
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
end
