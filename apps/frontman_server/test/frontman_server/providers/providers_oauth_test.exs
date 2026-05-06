defmodule FrontmanServer.Providers.ProvidersOAuthTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.OAuthToken

  describe "upsert_oauth_token/5" do
    test "inserts new token" do
      user = user_fixture()
      scope = %Scope{user: user}
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      assert {:ok, token} =
               Providers.upsert_oauth_token(
                 scope,
                 "anthropic",
                 "access_123",
                 "refresh_456",
                 expires_at
               )

      assert token.provider == "anthropic"
      assert token.access_token == "access_123"
      assert token.refresh_token == "refresh_456"
      assert token.expires_at == expires_at
      assert token.user_id == user.id
    end

    test "updates existing token (upsert)" do
      user = user_fixture()
      scope = %Scope{user: user}

      expires_at1 =
        DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      expires_at2 =
        DateTime.utc_now() |> DateTime.add(7200, :second) |> DateTime.truncate(:second)

      # Insert first
      {:ok, _} =
        Providers.upsert_oauth_token(scope, "anthropic", "access_1", "refresh_1", expires_at1)

      # Upsert with new values
      {:ok, token} =
        Providers.upsert_oauth_token(scope, "anthropic", "access_2", "refresh_2", expires_at2)

      assert token.access_token == "access_2"
      assert token.refresh_token == "refresh_2"
      assert token.expires_at == expires_at2

      # Should only be one token in DB
      assert Repo.aggregate(OAuthToken, :count) == 1
    end

    test "normalizes provider to lowercase" do
      user = user_fixture()
      scope = %Scope{user: user}
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      {:ok, token} =
        Providers.upsert_oauth_token(scope, "ANTHROPIC", "access", "refresh", expires_at)

      assert token.provider == "anthropic"
    end
  end

  describe "get_oauth_token/2" do
    test "returns token when exists" do
      user = user_fixture()
      scope = %Scope{user: user}
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      {:ok, _} = Providers.upsert_oauth_token(scope, "anthropic", "access", "refresh", expires_at)

      token = Providers.get_oauth_token(scope, "anthropic")

      assert %OAuthToken{} = token
      assert token.provider == "anthropic"
    end

    test "returns nil when not exists" do
      user = user_fixture()
      scope = %Scope{user: user}

      assert Providers.get_oauth_token(scope, "anthropic") == nil
    end
  end

  describe "has_oauth_token?/2" do
    test "returns true when token exists" do
      user = user_fixture()
      scope = %Scope{user: user}
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      {:ok, _} = Providers.upsert_oauth_token(scope, "anthropic", "access", "refresh", expires_at)

      assert Providers.has_oauth_token?(scope, "anthropic")
    end

    test "returns false when token does not exist" do
      user = user_fixture()
      scope = %Scope{user: user}

      refute Providers.has_oauth_token?(scope, "anthropic")
    end
  end

  describe "delete_oauth_token/2" do
    test "deletes existing token" do
      user = user_fixture()
      scope = %Scope{user: user}
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      {:ok, _} = Providers.upsert_oauth_token(scope, "anthropic", "access", "refresh", expires_at)

      assert :ok = Providers.delete_oauth_token(scope, "anthropic")
      assert Providers.get_oauth_token(scope, "anthropic") == nil
    end

    test "returns error when token does not exist" do
      user = user_fixture()
      scope = %Scope{user: user}

      assert {:error, :not_found} = Providers.delete_oauth_token(scope, "anthropic")
    end
  end

  describe "get_valid_oauth_token/2" do
    test "returns access token when not expired" do
      user = user_fixture()
      scope = %Scope{user: user}
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      {:ok, _} =
        Providers.upsert_oauth_token(scope, "anthropic", "valid_access", "refresh", expires_at)

      assert {:ok, "valid_access"} = Providers.get_valid_oauth_token(scope, "anthropic")
    end

    test "returns error when no token exists" do
      user = user_fixture()
      scope = %Scope{user: user}

      assert {:error, :no_oauth_token} = Providers.get_valid_oauth_token(scope, "anthropic")
    end

    # Note: Testing token refresh would require mocking HTTP requests to Anthropic
    # which is out of scope for unit tests - integration tests would cover this
  end

  describe "resolve_api_key/2 with OAuth" do
    test "returns oauth_token with transformation opts when available for anthropic" do
      user = user_fixture()
      scope = %Scope{user: user}
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      {:ok, _} =
        Providers.upsert_oauth_token(scope, "anthropic", "oauth_access", "refresh", expires_at)

      # Even with env_api_keys in scope, OAuth should take priority
      scope = Scope.with_env_api_keys(scope, %{"anthropic" => "env_key"})
      result = Providers.resolve_api_key(scope, "anthropic")

      # OAuth returns 3-tuple with transformation options for Claude Code
      assert {:oauth_token, "oauth_access", opts} = result
      assert Keyword.get(opts, :requires_mcp_prefix) == true
      assert Keyword.get(opts, :with_claude_subscription) == true
    end

    test "falls back to user_key when no OAuth token" do
      user = user_fixture()
      scope = %Scope{user: user}

      # Save a user API key
      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "user_api_key")

      result = Providers.resolve_api_key(scope, "anthropic")

      assert {:user_key, "user_api_key"} = result
    end

    test "OAuth only applies to anthropic provider" do
      user = user_fixture()
      scope = %Scope{user: user}

      # OAuth is not supported for openrouter, so should use other resolution
      scope = Scope.with_env_api_keys(scope, %{"openrouter" => "env_key"})
      result = Providers.resolve_api_key(scope, "openrouter")

      assert {:env_key, "env_key"} = result
    end
  end
end
