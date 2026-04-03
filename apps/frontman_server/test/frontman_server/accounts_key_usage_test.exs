defmodule FrontmanServer.ProvidersTest do
  use FrontmanServer.DataCase

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers

  import FrontmanServer.Test.Fixtures.Accounts

  describe "user key usage" do
    test "increments usage and returns remaining" do
      user = user_fixture()
      scope = Scope.for_user(user)

      assert Providers.get_usage(scope, "openrouter") == nil
      assert Providers.get_usage_remaining(scope, "openrouter") == Providers.usage_limit()

      {:ok, usage} = Providers.increment_usage(scope, "openrouter")
      assert usage.count == 1

      remaining = Providers.get_usage_remaining(scope, "openrouter")
      assert remaining == Providers.usage_limit() - 1
    end

    test "limits usage when limit reached" do
      user = user_fixture()
      scope = Scope.for_user(user)
      limit = Providers.usage_limit()

      Enum.each(1..limit, fn _ ->
        {:ok, _} = Providers.increment_usage(scope, "openrouter")
      end)

      assert Providers.has_remaining_usage?(scope, "openrouter") == false
      assert Providers.get_usage_remaining(scope, "openrouter") == 0
    end
  end

  describe "resolve_api_key" do
    test "returns user key when present" do
      user = user_fixture()
      scope = Scope.for_user(user)
      {:ok, _} = Providers.upsert_api_key(scope, "openrouter", "sk-user-123")

      assert {:user_key, "sk-user-123"} = Providers.resolve_api_key(scope, "openrouter")
    end
  end
end
