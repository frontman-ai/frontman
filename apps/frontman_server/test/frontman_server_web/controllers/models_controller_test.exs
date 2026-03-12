defmodule FrontmanServerWeb.ModelsControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  import FrontmanServer.ProvidersFixtures

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers

  describe "GET /api/models" do
    setup context do
      context = register_and_log_in_user(context)
      scope = Scope.for_user(context.user)
      Map.put(context, :scope, scope)
    end

    test "returns free-tier OpenRouter models when user has no key", %{conn: conn} do
      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 200)

      assert %{"providers" => providers, "defaultModel" => default_model} = response
      assert length(providers) == 1

      [openrouter] = providers
      assert openrouter["id"] == "openrouter"
      model_values = Enum.map(openrouter["models"], & &1["value"])

      assert "google/gemini-3-flash-preview" in model_values
      assert "anthropic/claude-haiku-4.5" in model_values
      refute "anthropic/claude-opus-4.6" in model_values
      refute "openai/gpt-5.3-codex" in model_values

      assert default_model["provider"] == "openrouter"
      assert default_model["value"] == "google/gemini-3-flash-preview"
    end

    test "returns full OpenRouter models when user has a stored API key", %{
      conn: conn,
      scope: scope
    } do
      {:ok, _} = Providers.upsert_api_key(scope, "openrouter", "sk-test-key")

      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 200)

      [openrouter] = response["providers"]
      model_values = Enum.map(openrouter["models"], & &1["value"])

      assert "anthropic/claude-opus-4.6" in model_values
      assert "openai/gpt-5.3-codex" in model_values
      assert "google/gemini-3-flash-preview" in model_values
    end

    test "returns full OpenRouter models when hasEnvKey=true", %{conn: conn} do
      conn = get(conn, ~p"/api/models?hasEnvKey=true")
      response = json_response(conn, 200)

      [openrouter] = response["providers"]
      model_values = Enum.map(openrouter["models"], & &1["value"])

      assert "anthropic/claude-opus-4.6" in model_values
      assert "openai/gpt-5.3-codex" in model_values
    end

    test "includes Anthropic provider when user has Anthropic OAuth", %{
      conn: conn,
      scope: scope
    } do
      setup_oauth_token(scope, "anthropic")

      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 200)

      provider_ids = Enum.map(response["providers"], & &1["id"])
      assert "anthropic" in provider_ids
      assert "openrouter" in provider_ids

      anthropic = Enum.find(response["providers"], &(&1["id"] == "anthropic"))
      model_values = Enum.map(anthropic["models"], & &1["value"])
      assert "claude-opus-4-6" in model_values
      assert "claude-sonnet-4-5" in model_values

      assert response["defaultModel"]["provider"] == "anthropic"
      assert response["defaultModel"]["value"] == "claude-sonnet-4-5"
    end

    test "includes ChatGPT provider when user has ChatGPT OAuth", %{conn: conn, scope: scope} do
      setup_oauth_token(scope, "chatgpt")

      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 200)

      provider_ids = Enum.map(response["providers"], & &1["id"])
      assert "openai" in provider_ids
      assert "openrouter" in provider_ids

      openai = Enum.find(response["providers"], &(&1["id"] == "openai"))
      model_values = Enum.map(openai["models"], & &1["value"])
      assert "gpt-5.3-codex" in model_values
      assert "gpt-5.2-codex" in model_values
      refute "codex-5.3" in model_values

      assert response["defaultModel"]["provider"] == "openai"
      assert response["defaultModel"]["value"] == "gpt-5.4"
    end

    test "ChatGPT takes default priority over Anthropic", %{conn: conn, scope: scope} do
      setup_oauth_token(scope, "anthropic")
      setup_oauth_token(scope, "chatgpt")

      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 200)

      provider_ids = Enum.map(response["providers"], & &1["id"])
      assert "openai" in provider_ids
      assert "anthropic" in provider_ids
      assert "openrouter" in provider_ids

      assert response["defaultModel"]["provider"] == "openai"
    end

    test "includes Anthropic provider when hasAnthropicEnvKey=true", %{conn: conn} do
      conn = get(conn, ~p"/api/models?hasAnthropicEnvKey=true")
      response = json_response(conn, 200)

      provider_ids = Enum.map(response["providers"], & &1["id"])
      assert "anthropic" in provider_ids
      assert "openrouter" in provider_ids

      anthropic = Enum.find(response["providers"], &(&1["id"] == "anthropic"))
      model_values = Enum.map(anthropic["models"], & &1["value"])
      assert "claude-sonnet-4-5" in model_values
      assert "claude-opus-4-6" in model_values

      assert response["defaultModel"]["provider"] == "anthropic"
    end

    test "includes Anthropic provider when user has stored Anthropic API key", %{
      conn: conn,
      scope: scope
    } do
      {:ok, _} = Providers.upsert_api_key(scope, "anthropic", "sk-ant-stored")

      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 200)

      provider_ids = Enum.map(response["providers"], & &1["id"])
      assert "anthropic" in provider_ids
    end

    test "Anthropic env key does not affect OpenRouter tier", %{conn: conn} do
      conn = get(conn, ~p"/api/models?hasAnthropicEnvKey=true")
      response = json_response(conn, 200)

      openrouter = Enum.find(response["providers"], &(&1["id"] == "openrouter"))
      model_values = Enum.map(openrouter["models"], & &1["value"])

      refute "anthropic/claude-opus-4.6" in model_values
    end

    test "both env keys enable both providers at full tier", %{conn: conn} do
      conn = get(conn, ~p"/api/models?hasEnvKey=true&hasAnthropicEnvKey=true")
      response = json_response(conn, 200)

      provider_ids = Enum.map(response["providers"], & &1["id"])
      assert "anthropic" in provider_ids
      assert "openrouter" in provider_ids

      openrouter = Enum.find(response["providers"], &(&1["id"] == "openrouter"))
      or_values = Enum.map(openrouter["models"], & &1["value"])
      assert "anthropic/claude-opus-4.6" in or_values

      assert response["defaultModel"]["provider"] == "anthropic"
    end

    test "returns unauthorized without user" do
      conn = build_conn()
      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 401)

      assert response["error"] == "authentication_required"
    end
  end
end
