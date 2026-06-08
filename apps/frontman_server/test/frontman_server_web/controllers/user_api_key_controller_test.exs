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

      {:ok, {"openrouter:test-model", llm_opts}} =
        Providers.prepare_llm_args(scope, "openrouter:test-model")

      assert llm_opts[:api_key] == "sk-test-123"
    end

    test "stores Fireworks keys for logged-in user", %{conn: conn, user: user} do
      params = %{"provider" => "fireworks_ai", "key" => "sk-fireworks-test-123"}

      conn = post(conn, ~p"/api/user/api-keys", params)
      response = json_response(conn, 200)

      assert response["status"] == "ok"
      assert response["provider"] == "fireworks_ai"

      scope = Scope.for_user(user)

      {:ok, {"fireworks_ai:test-model", llm_opts}} =
        Providers.prepare_llm_args(scope, "fireworks_ai:test-model")

      assert llm_opts[:api_key] == "sk-fireworks-test-123"
    end

    test "stores Fireworks keys without affecting other users", %{conn: conn, user: user} do
      other_user = AccountsFixtures.user_fixture()
      other_scope = Scope.for_user(other_user)
      {:ok, _} = Providers.upsert_api_key(other_scope, "fireworks_ai", "sk-fireworks-other-user")

      conn =
        post(conn, ~p"/api/user/api-keys", %{
          "provider" => "fireworks_ai",
          "key" => "sk-fireworks-current-user"
        })

      response = json_response(conn, 200)

      assert response["status"] == "ok"

      {:ok, {"fireworks_ai:test-model", llm_opts}} =
        Providers.prepare_llm_args(Scope.for_user(user), "fireworks_ai:test-model")

      assert llm_opts[:api_key] == "sk-fireworks-current-user"

      {:ok, {"fireworks_ai:test-model", other_llm_opts}} =
        Providers.prepare_llm_args(other_scope, "fireworks_ai:test-model")

      assert other_llm_opts[:api_key] == "sk-fireworks-other-user"
    end

    test "returns unauthorized without user" do
      conn = build_conn()
      conn = post(conn, ~p"/api/user/api-keys", %{provider: "openrouter", key: "sk-test"})
      response = json_response(conn, 401)

      assert response["error"] == "authentication_required"
    end
  end

  describe "GET /api/user/api-keys" do
    setup :register_and_log_in_user

    test "returns saved key metadata", %{conn: conn} do
      conn = get(conn, ~p"/api/user/api-keys")
      response = json_response(conn, 200)

      assert response["providers"] == []
    end

    test "returns saved key providers", %{conn: conn, user: user} do
      {:ok, _} =
        Providers.upsert_api_key(Scope.for_user(user), "fireworks_ai", "sk-fireworks-user-key")

      conn = get(conn, ~p"/api/user/api-keys")
      response = json_response(conn, 200)

      assert response["providers"] == ["fireworks_ai"]
    end

    test "returns saved key providers for the logged-in user only", %{conn: conn} do
      other_user = AccountsFixtures.user_fixture()
      other_scope = Scope.for_user(other_user)
      {:ok, _} = Providers.upsert_api_key(other_scope, "fireworks_ai", "sk-fireworks-other-user")

      conn = get(conn, ~p"/api/user/api-keys")
      response = json_response(conn, 200)

      assert response["providers"] == []
    end

    test "returns unauthorized without user" do
      conn = build_conn()
      conn = get(conn, ~p"/api/user/api-keys")
      response = json_response(conn, 401)

      assert response["error"] == "authentication_required"
    end
  end
end
