defmodule FrontmanServer.Providers.PrepareApiKeyTest do
  @moduledoc """
  Integration tests for the full `Providers.prepare_api_key/4` resolution chain.

  Tests the priority order: OAuth > user key > env key > server key,
  plus quota checks on server keys. This is the primary entry point for
  all LLM key resolution in the system.
  """
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.AccountsFixtures

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.ResolvedKey

  describe "prepare_api_key/4 resolution priority" do
    test "resolves OAuth token as highest priority for anthropic" do
      user = user_fixture()
      scope = %Scope{user: user}
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      # Set up ALL key types: OAuth, user key, env key
      {:ok, _} =
        Providers.upsert_oauth_token(scope, "anthropic", "oauth_access", "refresh", expires_at)

      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")
      env_api_key = %{"anthropic" => "env_key_789"}

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5", env_api_key)

      assert resolved.key_source == :oauth_token
      assert resolved.api_key == "oauth_access"
      assert resolved.provider == "anthropic"
      assert resolved.requires_mcp_prefix == true
      assert resolved.identity_override =~ "Claude Code"
      assert resolved.oauth_mode == true
    end

    test "falls back to user key when no OAuth token" do
      user = user_fixture()
      scope = %Scope{user: user}

      # User key + env key, but no OAuth
      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_key_456")
      env_api_key = %{"anthropic" => "env_key_789"}

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5", env_api_key)

      assert resolved.key_source == :user_key
      assert resolved.api_key == "user_key_456"
      assert resolved.provider == "anthropic"
      # Non-OAuth keys don't get Claude Code transformations
      assert resolved.requires_mcp_prefix == false
      assert resolved.identity_override == nil
      assert resolved.oauth_mode == false
    end

    test "falls back to env key when no OAuth or user key" do
      user = user_fixture()
      scope = %Scope{user: user}

      env_api_key = %{"anthropic" => "env_key_789"}

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5", env_api_key)

      assert resolved.key_source == :env_key
      assert resolved.api_key == "env_key_789"
      assert resolved.provider == "anthropic"
    end

    test "falls back to server key when no OAuth, user key, or env key" do
      user = user_fixture()
      scope = %Scope{user: user}

      # Temporarily set a server key
      original = Application.get_env(:frontman_server, :anthropic_api_key)
      Application.put_env(:frontman_server, :anthropic_api_key, "server_key_abc")

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5", %{})

      assert resolved.key_source == :server_key
      assert resolved.api_key == "server_key_abc"
      assert resolved.provider == "anthropic"

      # Restore
      if original,
        do: Application.put_env(:frontman_server, :anthropic_api_key, original),
        else: Application.delete_env(:frontman_server, :anthropic_api_key)
    end

    test "returns :no_api_key when no key source is available" do
      user = user_fixture()
      scope = %Scope{user: user}

      # Clear server key
      original = Application.get_env(:frontman_server, :anthropic_api_key)
      Application.delete_env(:frontman_server, :anthropic_api_key)

      result = Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5", %{})

      assert {:error, :no_api_key} = result

      # Restore
      if original,
        do: Application.put_env(:frontman_server, :anthropic_api_key, original)
    end

    test "server key checks usage quota" do
      user = user_fixture()
      scope = %Scope{user: user}

      # Set a server key and exhaust usage
      original = Application.get_env(:frontman_server, :anthropic_api_key)
      Application.put_env(:frontman_server, :anthropic_api_key, "server_key_quota")

      limit = Providers.usage_limit()

      for _ <- 1..limit do
        Providers.increment_usage(scope, "anthropic")
      end

      result = Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5", %{})

      assert {:error, :usage_limit_exceeded} = result

      # Restore
      if original,
        do: Application.put_env(:frontman_server, :anthropic_api_key, original),
        else: Application.delete_env(:frontman_server, :anthropic_api_key)
    end

    test "skip_quota bypasses usage limit on server key" do
      user = user_fixture()
      scope = %Scope{user: user}

      original = Application.get_env(:frontman_server, :anthropic_api_key)
      Application.put_env(:frontman_server, :anthropic_api_key, "server_key_skip")

      limit = Providers.usage_limit()

      for _ <- 1..limit do
        Providers.increment_usage(scope, "anthropic")
      end

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "anthropic:claude-sonnet-4-5", %{}, skip_quota: true)

      assert resolved.key_source == :server_key
      assert resolved.api_key == "server_key_skip"

      if original,
        do: Application.put_env(:frontman_server, :anthropic_api_key, original),
        else: Application.delete_env(:frontman_server, :anthropic_api_key)
    end

    test "openrouter env key resolves correctly" do
      user = user_fixture()
      scope = %Scope{user: user}

      env_api_key = %{"openrouter" => "sk-or-env-test"}

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, "openrouter:openai/gpt-5.1-codex", env_api_key)

      assert resolved.key_source == :env_key
      assert resolved.api_key == "sk-or-env-test"
      assert resolved.provider == "openrouter"
      assert resolved.model == "openrouter:openai/gpt-5.1-codex"
    end

    test "defaults to openrouter when model is nil" do
      user = user_fixture()
      scope = %Scope{user: user}

      original = Application.get_env(:frontman_server, :openrouter_api_key)
      Application.put_env(:frontman_server, :openrouter_api_key, "server_or_key")

      {:ok, %ResolvedKey{} = resolved} = Providers.prepare_api_key(scope, nil, %{})

      assert resolved.provider == "openrouter"

      if original,
        do: Application.put_env(:frontman_server, :openrouter_api_key, original),
        else: Application.delete_env(:frontman_server, :openrouter_api_key)
    end
  end
end
