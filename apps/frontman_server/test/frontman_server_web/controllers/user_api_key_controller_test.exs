defmodule FrontmanServerWeb.UserApiKeyControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  describe "POST /api/user/api-keys" do
    setup :register_and_log_in_user

    test "stores provider key for logged-in user", %{conn: conn, user: user} do
      params = %{"provider" => "openrouter", "key" => "sk-test-123"}

      conn = post(conn, ~p"/api/user/api-keys", params)
      response = json_response(conn, 200)

      assert response["status"] == "ok"
      assert response["provider"] == "openrouter"

      scope = Scope.for_user(user)
      api_key = Providers.get_api_key(scope, "openrouter")
      assert api_key.key == "sk-test-123"
    end

    test "stores Fireworks keys for logged-in user", %{conn: conn, user: user} do
      params = %{"provider" => "fireworks", "key" => "sk-fireworks-test-123"}

      conn = post(conn, ~p"/api/user/api-keys", params)
      response = json_response(conn, 200)

      assert response["status"] == "ok"
      assert response["provider"] == "fireworks"

      scope = Scope.for_user(user)
      api_key = Providers.get_api_key(scope, "fireworks")
      assert api_key.key == "sk-fireworks-test-123"
    end

    test "stores Fireworks keys without affecting other users", %{conn: conn, user: user} do
      other_user = AccountsFixtures.user_fixture()
      other_scope = Scope.for_user(other_user)
      {:ok, _} = Providers.upsert_api_key(other_scope, "fireworks", "sk-fireworks-other-user")

      conn =
        post(conn, ~p"/api/user/api-keys", %{
          "provider" => "fireworks",
          "key" => "sk-fireworks-current-user"
        })

      response = json_response(conn, 200)

      assert response["status"] == "ok"

      assert Providers.get_api_key(Scope.for_user(user), "fireworks").key ==
               "sk-fireworks-current-user"

      assert Providers.get_api_key(other_scope, "fireworks").key == "sk-fireworks-other-user"
    end

    test "returns unauthorized without user" do
      conn = build_conn()
      conn = post(conn, ~p"/api/user/api-keys", %{provider: "openrouter", key: "sk-test"})
      response = json_response(conn, 401)

      assert response["error"] == "authentication_required"
    end
  end

  describe "GET /api/user/api-key-usage" do
    setup :register_and_log_in_user

    test "returns usage metadata", %{conn: conn} do
      conn = get(conn, ~p"/api/user/api-key-usage")
      response = json_response(conn, 200)

      assert response["limit"] == Providers.usage_limit()
      assert response["used"] == 0
      assert response["remaining"] == Providers.usage_limit()
      assert response["hasUserKey"] == false
      assert response["hasServerKey"] in [true, false]
    end

    test "returns usage metadata for Fireworks", %{conn: conn, user: user} do
      {:ok, _} =
        Providers.upsert_api_key(Scope.for_user(user), "fireworks", "sk-fireworks-user-key")

      conn = get(conn, ~p"/api/user/api-key-usage?provider=fireworks")
      response = json_response(conn, 200)

      assert response["limit"] == Providers.usage_limit()
      assert response["used"] == 0
      assert response["remaining"] == Providers.usage_limit()
      assert response["hasUserKey"] == true
      assert response["hasServerKey"] == true
    end

    test "returns Fireworks usage for the logged-in user only", %{conn: conn} do
      other_user = AccountsFixtures.user_fixture()
      other_scope = Scope.for_user(other_user)
      {:ok, _} = Providers.upsert_api_key(other_scope, "fireworks", "sk-fireworks-other-user")

      conn = get(conn, ~p"/api/user/api-key-usage?provider=fireworks")
      response = json_response(conn, 200)

      assert response["hasUserKey"] == false
    end

    test "returns unauthorized without user" do
      conn = build_conn()
      conn = get(conn, ~p"/api/user/api-key-usage")
      response = json_response(conn, 401)

      assert response["error"] == "authentication_required"
    end
  end
end
