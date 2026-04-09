defmodule FrontmanServer.Accounts.ScopeTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope

  describe "env_api_keys field" do
    test "defaults to empty map" do
      user = user_fixture()
      scope = Scope.for_user(user)
      assert scope.env_api_keys == %{}
    end

    test "with_env_api_keys/2 sets the field" do
      user = user_fixture()
      scope = Scope.for_user(user)
      enriched = Scope.with_env_api_keys(scope, %{"openrouter" => "sk-or-test"})
      assert enriched.env_api_keys == %{"openrouter" => "sk-or-test"}
      assert enriched.user == scope.user
    end

    test "with_env_api_keys/2 defaults to empty map when nil passed" do
      user = user_fixture()
      scope = Scope.for_user(user)
      enriched = Scope.with_env_api_keys(scope, nil)
      assert enriched.env_api_keys == %{}
    end
  end
end
