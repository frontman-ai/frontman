defmodule FrontmanServer.Accounts.ScopeTest do
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Accounts.Scope

  describe "for_user/1" do
    test "builds a user scope" do
      user = user_fixture()
      scope = Scope.for_user(user)

      assert scope.user == user
      assert scope.organization == nil
    end
  end
end
