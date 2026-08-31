defmodule FrontmanServerWeb.UserApiKeyControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  @fireworks_model "fireworks_ai:accounts/fireworks/routers/kimi-k2p6-turbo"

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Test.Fixtures.Accounts, as: AccountsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)

    %{embedded_auth: embedded_client_auth(user), user: user, scope: scope}
  end

  describe "POST /api/user/api-keys" do
    test "stores provider key for bearer-authenticated user", %{
      conn: conn,
      embedded_auth: auth,
      user: user
    } do
      params = %{"provider" => "openrouter", "key" => "sk-test-123"}

      conn = bearer_post(conn, auth, ~p"/api/user/api-keys", params)
      response = json_response(conn, 200)

      assert response["status"] == "ok"
      assert response["provider"] == "openrouter"

      scope = Scope.for_user(user)

      {:ok, {%LLMDB.Model{provider: :openrouter}, llm_opts}} =
        Providers.resolve_model_access(scope, "openrouter:anthropic/claude-fable-5")

      assert llm_opts[:api_key] == "sk-test-123"
    end

    test "stores Fireworks keys for bearer-authenticated user", %{
      conn: conn,
      embedded_auth: auth,
      user: user
    } do
      params = %{"provider" => "fireworks_ai", "key" => "sk-fireworks-test-123"}

      conn = bearer_post(conn, auth, ~p"/api/user/api-keys", params)
      response = json_response(conn, 200)

      assert response["status"] == "ok"
      assert response["provider"] == "fireworks_ai"

      scope = Scope.for_user(user)

      assert %{groups: groups} = Providers.available_models(scope)

      assert %{id: "fireworks_ai", options: [%{value: "fireworks_ai:" <> _} | _]} =
               Enum.find(groups, &(&1.id == "fireworks_ai"))

      {:ok, {%LLMDB.Model{provider: :fireworks_ai}, llm_opts}} =
        Providers.resolve_model_access(scope, @fireworks_model)

      assert llm_opts[:api_key] == "sk-fireworks-test-123"
    end

    test "stores Fireworks keys without affecting other users", %{
      conn: conn,
      embedded_auth: auth,
      user: user
    } do
      other_user = AccountsFixtures.user_fixture()
      other_scope = Scope.for_user(other_user)
      :ok = Providers.upsert_api_key(other_scope, "fireworks_ai", "sk-fireworks-other-user")

      conn =
        bearer_post(conn, auth, ~p"/api/user/api-keys", %{
          "provider" => "fireworks_ai",
          "key" => "sk-fireworks-current-user"
        })

      response = json_response(conn, 200)

      assert response["status"] == "ok"

      {:ok, {%LLMDB.Model{provider: :fireworks_ai}, llm_opts}} =
        Providers.resolve_model_access(Scope.for_user(user), @fireworks_model)

      assert llm_opts[:api_key] == "sk-fireworks-current-user"

      {:ok, {%LLMDB.Model{provider: :fireworks_ai}, other_llm_opts}} =
        Providers.resolve_model_access(other_scope, @fireworks_model)

      assert other_llm_opts[:api_key] == "sk-fireworks-other-user"
    end

    test "returns unauthorized without bearer token" do
      conn = build_conn()
      conn = post(conn, ~p"/api/user/api-keys", %{provider: "openrouter", key: "sk-test"})
      response = json_response(conn, 401)

      assert response["error"] == "authentication_required"
    end

    test "returns unauthorized for session-only authentication", %{user: user} do
      conn =
        build_conn()
        |> log_in_user(user)
        |> post(~p"/api/user/api-keys", %{provider: "openrouter", key: "sk-test"})

      assert json_response(conn, 401)["error"] == "authentication_required"
    end
  end

  describe "GET /api/user/api-keys" do
    test "returns saved key metadata", %{conn: conn, embedded_auth: auth} do
      conn = bearer_get(conn, auth, ~p"/api/user/api-keys")
      response = json_response(conn, 200)

      assert response["providers"] == []
    end

    test "returns saved key providers", %{conn: conn, embedded_auth: auth, user: user} do
      :ok =
        Providers.upsert_api_key(Scope.for_user(user), "fireworks_ai", "sk-fireworks-user-key")

      conn = bearer_get(conn, auth, ~p"/api/user/api-keys")
      response = json_response(conn, 200)

      assert response["providers"] == ["fireworks_ai"]
    end

    test "returns saved key providers for the bearer-authenticated user only", %{
      conn: conn,
      embedded_auth: auth
    } do
      other_user = AccountsFixtures.user_fixture()
      other_scope = Scope.for_user(other_user)
      :ok = Providers.upsert_api_key(other_scope, "fireworks_ai", "sk-fireworks-other-user")

      conn = bearer_get(conn, auth, ~p"/api/user/api-keys")
      response = json_response(conn, 200)

      assert response["providers"] == []
    end

    test "returns unauthorized without bearer token" do
      conn = build_conn()
      conn = get(conn, ~p"/api/user/api-keys")
      response = json_response(conn, 401)

      assert response["error"] == "authentication_required"
    end

    test "returns unauthorized for session-only authentication", %{user: user} do
      conn =
        build_conn()
        |> log_in_user(user)
        |> get(~p"/api/user/api-keys")

      assert json_response(conn, 401)["error"] == "authentication_required"
    end
  end
end
