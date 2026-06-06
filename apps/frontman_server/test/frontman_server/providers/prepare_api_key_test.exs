defmodule FrontmanServer.Providers.PrepareApiKeyTest do
  @moduledoc """
  Integration tests for the full `Providers.prepare_api_key/2` resolution chain.

  Tests the priority order: OAuth > user key > env key.
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

  describe "prepare_api_key/2 resolution priority" do
    test "resolves OAuth token as highest priority for anthropic", %{scope: scope} do
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(scope, "anthropic", "oauth_access", "refresh", expires_at)

      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")
      scope = Scope.with_env_api_keys(scope, %{"anthropic" => "env_key_789"})

      {:ok, resolved} = Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5")

      assert resolved.provider == "anthropic"

      {model, llm_opts} = Providers.to_llm_args(resolved)
      assert model == "anthropic:claude-sonnet-4-5"
      assert llm_opts[:access_token] == "oauth_access"
      assert llm_opts[:auth_mode] == :oauth
      assert llm_opts[:with_claude_subscription] == true
    end

    test "falls back to user key when no OAuth token", %{scope: scope} do
      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")
      scope = Scope.with_env_api_keys(scope, %{"anthropic" => "env_key_789"})

      {:ok, resolved} = Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5")

      assert resolved.provider == "anthropic"

      {_model, llm_opts} = Providers.to_llm_args(resolved)
      assert llm_opts[:api_key] == "user_key_456"
    end

    test "falls back to env key when no OAuth or user key", %{scope: scope} do
      scope = Scope.with_env_api_keys(scope, %{"anthropic" => "env_key_789"})

      {:ok, resolved} = Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5")

      assert resolved.provider == "anthropic"

      {_model, llm_opts} = Providers.to_llm_args(resolved)
      assert llm_opts[:api_key] == "env_key_789"
    end

    test "returns :no_api_key when no key source is available", %{scope: scope} do
      assert {:error, :no_api_key} =
               Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5")
    end

    test "openrouter env key resolves correctly", %{scope: scope} do
      scope = Scope.with_env_api_keys(scope, %{"openrouter" => "sk-or-env-test"})

      {:ok, resolved} = Providers.prepare_api_key(scope, "openrouter:openai/gpt-5.5")

      assert resolved.provider == "openrouter"
      assert resolved.model == "openrouter:openai/gpt-5.5"

      {_model, llm_opts} = Providers.to_llm_args(resolved)
      assert llm_opts[:api_key] == "sk-or-env-test"
    end

    test "chatgpt oauth resolves codex args", %{scope: scope} do
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(scope, "chatgpt", "chatgpt_access", "refresh", expires_at, %{
          "account_id" => "acc-789"
        })

      {:ok, resolved} = Providers.prepare_api_key(scope, "openai:gpt-5.3-codex")

      {model, llm_opts} = Providers.to_llm_args(resolved, max_tokens: 16_384)

      assert %{provider: :openai_codex, id: "gpt-5.3-codex"} = model
      assert llm_opts[:access_token] == "chatgpt_access"
      assert llm_opts[:auth_mode] == :oauth
      assert llm_opts[:base_url] == "https://chatgpt.com/backend-api/codex"
      assert llm_opts[:chatgpt_account_id] == "acc-789"
      refute Keyword.has_key?(llm_opts, :max_tokens)
    end
  end

  describe "extract_env_keys/1" do
    test "extracts configured provider keys from ACP metadata" do
      assert Providers.extract_env_keys(%{
               "anthropicKeyValue" => "sk-ant-test",
               "openrouterKeyValue" => "sk-or-test",
               "fireworksKeyValue" => "sk-fw-test",
               "model" => %{"provider" => "fireworks", "value" => "model"}
             }) == %{
               "anthropic" => "sk-ant-test",
               "openrouter" => "sk-or-test",
               "fireworks" => "sk-fw-test"
             }
    end
  end
end
