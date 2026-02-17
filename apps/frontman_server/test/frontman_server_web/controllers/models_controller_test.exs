defmodule FrontmanServerWeb.ModelsControllerTest do
  use FrontmanServerWeb.ConnCase, async: true

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers

  describe "GET /api/models" do
    setup :register_and_log_in_user

    test "returns free-tier OpenRouter models when user has no key", %{conn: conn} do
      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 200)

      assert %{"providers" => providers, "defaultModel" => default_model} = response

      # Should have exactly one provider (OpenRouter)
      assert length(providers) == 1

      [openrouter] = providers
      assert openrouter["id"] == "openrouter"
      model_values = Enum.map(openrouter["models"], & &1["value"])

      # Free tier should contain these specific models
      assert "google/gemini-3-flash-preview" in model_values
      assert "anthropic/claude-haiku-4.5" in model_values
      assert "moonshotai/kimi-k2.5" in model_values
      assert "minimax/minimax-m2.5" in model_values

      # Free tier should NOT contain premium models
      refute "anthropic/claude-opus-4.6" in model_values
      refute "openai/gpt-5.3-codex" in model_values
      refute "openai/gpt-5.2" in model_values

      # Default model should still be gemini flash
      assert default_model["provider"] == "openrouter"
      assert default_model["value"] == "google/gemini-3-flash-preview"
    end

    test "returns full OpenRouter models when user has a stored API key", %{
      conn: conn,
      user: user
    } do
      scope = Scope.for_user(user)
      {:ok, _} = Providers.upsert_api_key(scope, "openrouter", "sk-test-key")

      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 200)

      [openrouter] = response["providers"]
      model_values = Enum.map(openrouter["models"], & &1["value"])

      # Full tier should contain all models including new ones
      assert "anthropic/claude-opus-4.6" in model_values
      assert "openai/gpt-5.3-codex" in model_values
      assert "openai/gpt-5.2" in model_values
      assert "google/gemini-3-flash-preview" in model_values
    end

    test "returns full OpenRouter models when hasEnvKey=true", %{conn: conn} do
      conn = get(conn, ~p"/api/models?hasEnvKey=true")
      response = json_response(conn, 200)

      [openrouter] = response["providers"]
      model_values = Enum.map(openrouter["models"], & &1["value"])

      # Full tier via env key
      assert "anthropic/claude-opus-4.6" in model_values
      assert "openai/gpt-5.3-codex" in model_values
      assert "openai/gpt-5.2" in model_values
    end

    test "includes Anthropic provider when user has Anthropic OAuth", %{conn: conn, user: user} do
      scope = Scope.for_user(user)
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(
          scope,
          "anthropic",
          "access-token",
          "refresh-token",
          expires_at
        )

      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 200)

      provider_ids = Enum.map(response["providers"], & &1["id"])
      assert "anthropic" in provider_ids
      assert "openrouter" in provider_ids

      anthropic = Enum.find(response["providers"], &(&1["id"] == "anthropic"))
      model_values = Enum.map(anthropic["models"], & &1["value"])
      assert "claude-opus-4-6" in model_values
      assert "claude-sonnet-4-5" in model_values

      # Default should be Anthropic when OAuth is connected
      assert response["defaultModel"]["provider"] == "anthropic"
      assert response["defaultModel"]["value"] == "claude-sonnet-4-5"
    end

    test "includes ChatGPT provider when user has ChatGPT OAuth", %{conn: conn, user: user} do
      scope = Scope.for_user(user)
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(
          scope,
          "chatgpt",
          "access-token",
          "refresh-token",
          expires_at
        )

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

      # Default should be ChatGPT when OAuth is connected
      assert response["defaultModel"]["provider"] == "openai"
      assert response["defaultModel"]["value"] == "gpt-5.1-codex-max"
    end

    test "ChatGPT takes default priority over Anthropic", %{conn: conn, user: user} do
      scope = Scope.for_user(user)
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _} =
        Providers.upsert_oauth_token(
          scope,
          "anthropic",
          "access-token",
          "refresh-token",
          expires_at
        )

      {:ok, _} =
        Providers.upsert_oauth_token(
          scope,
          "chatgpt",
          "access-token",
          "refresh-token",
          expires_at
        )

      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 200)

      provider_ids = Enum.map(response["providers"], & &1["id"])
      assert "openai" in provider_ids
      assert "anthropic" in provider_ids
      assert "openrouter" in provider_ids

      # ChatGPT > Anthropic > OpenRouter
      assert response["defaultModel"]["provider"] == "openai"
    end

    test "returns unauthorized without user" do
      conn = build_conn()
      conn = get(conn, ~p"/api/models")
      response = json_response(conn, 401)

      assert response["error"] == "authentication_required"
    end
  end
end
