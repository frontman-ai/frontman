defmodule FrontmanServer.Providers.PrepareApiKeyTest do
  @moduledoc """
  Integration tests for the full `Providers.prepare_api_key/3` resolution chain.

  Tests the priority order: OAuth > user key > env key > server key,
  plus quota checks on server keys. This is the primary entry point for
  all LLM key resolution in the system.
  """
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.ProvidersFixtures

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.ResolvedKey

  setup do
    user = user_fixture()
    scope = %Scope{user: user}
    {:ok, scope: scope}
  end

  describe "prepare_api_key/3 resolution priority" do
    test "resolves OAuth token as highest priority for anthropic", %{scope: scope} do
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(scope, "anthropic", "oauth_access", "refresh", expires_at)

      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")
      scope = Scope.with_env_api_keys(scope, %{"anthropic" => "env_key_789"})

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5")

      assert resolved.key_source == :oauth_token
      assert resolved.api_key == "oauth_access"
      assert resolved.provider == "anthropic"
      assert resolved.requires_mcp_prefix == true
      assert resolved.identity_override =~ "Claude Code"
      assert resolved.auth_mode == :oauth
    end

    test "falls back to user key when no OAuth token", %{scope: scope} do
      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")
      scope = Scope.with_env_api_keys(scope, %{"anthropic" => "env_key_789"})

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5")

      assert resolved.key_source == :user_key
      assert resolved.api_key == "user_key_456"
      assert resolved.provider == "anthropic"
      assert resolved.requires_mcp_prefix == false
      assert resolved.identity_override == nil
      assert resolved.auth_mode == :api_key
    end

    test "falls back to env key when no OAuth or user key", %{scope: scope} do
      scope = Scope.with_env_api_keys(scope, %{"anthropic" => "env_key_789"})

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5")

      assert resolved.key_source == :env_key
      assert resolved.api_key == "env_key_789"
      assert resolved.provider == "anthropic"
    end

    test "falls back to server key when no OAuth, user key, or env key", %{scope: scope} do
      with_server_key("anthropic", "server_key_abc")

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5")

      assert resolved.key_source == :server_key
      assert resolved.api_key == "server_key_abc"
      assert resolved.provider == "anthropic"
    end

    test "returns :no_api_key when no key source is available", %{scope: scope} do
      without_server_key("anthropic")

      assert {:error, :no_api_key} =
               Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5")
    end

    test "server key checks usage quota", %{scope: scope} do
      with_server_key("anthropic", "server_key_quota")

      for _ <- 1..Providers.usage_limit() do
        Providers.increment_usage(scope, "anthropic")
      end

      assert {:error, :usage_limit_exceeded} =
               Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5")
    end

    test "skip_quota bypasses usage limit on server key", %{scope: scope} do
      with_server_key("anthropic", "server_key_skip")

      for _ <- 1..Providers.usage_limit() do
        Providers.increment_usage(scope, "anthropic")
      end

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5", skip_quota: true)

      assert resolved.key_source == :server_key
      assert resolved.api_key == "server_key_skip"
    end

    test "openrouter env key resolves correctly", %{scope: scope} do
      scope = Scope.with_env_api_keys(scope, %{"openrouter" => "sk-or-env-test"})

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "openrouter:openai/gpt-5.5")

      assert resolved.key_source == :env_key
      assert resolved.api_key == "sk-or-env-test"
      assert resolved.provider == "openrouter"
      assert resolved.model == "openrouter:openai/gpt-5.5"
    end

    test "defaults to openrouter when model is nil", %{scope: scope} do
      with_server_key("openrouter", "server_or_key")

      {:ok, %ResolvedKey{} = resolved} = Providers.prepare_api_key(scope, nil)

      assert resolved.provider == "openrouter"
    end
  end
end
