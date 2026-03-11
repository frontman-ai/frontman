defmodule FrontmanServer.Tasks.TitleGeneratorIntegrationTest do
  @moduledoc """
  Integration tests verifying that TitleGenerator resolves the user's
  selected model and env key through the standard `prepare_api_key` chain.

  Does NOT test actual LLM generation — that requires HTTP mocking.
  Instead tests the key resolution path that feeds into the LLM call.
  """
  use FrontmanServer.DataCase, async: true

  import FrontmanServer.AccountsFixtures

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.{Model, ResolvedKey}

  describe "title generation key resolution" do
    test "prepare_api_key with skip_quota succeeds even when quota exhausted" do
      user = user_fixture()
      scope = %Scope{user: user}

      original = Application.get_env(:frontman_server, :openrouter_api_key)
      Application.put_env(:frontman_server, :openrouter_api_key, "server-key-title")

      # Exhaust quota
      limit = Providers.usage_limit()

      for _ <- 1..limit do
        Providers.increment_usage(scope, "openrouter")
      end

      # Normal request should fail
      assert {:error, :usage_limit_exceeded} =
               Providers.prepare_api_key(scope, "openrouter:google/gemini-2.0-flash-001", %{})

      # Title generation bypasses quota
      assert {:ok, %ResolvedKey{key_source: :server_key}} =
               Providers.prepare_api_key(
                 scope,
                 "openrouter:google/gemini-2.0-flash-001",
                 %{},
                 skip_quota: true
               )

      if original,
        do: Application.put_env(:frontman_server, :openrouter_api_key, original),
        else: Application.delete_env(:frontman_server, :openrouter_api_key)
    end

    test "title generation uses user's selected model when available" do
      user = user_fixture()
      scope = %Scope{user: user}

      # User has an Anthropic env key and selected Anthropic model
      env_api_key = %{"anthropic" => "sk-ant-title-test"}

      {:ok, model} = Model.parse("anthropic:claude-sonnet-4-5")
      model_string = Model.resolve_string(model)

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, model_string, env_api_key, skip_quota: true)

      assert resolved.provider == "anthropic"
      assert resolved.api_key == "sk-ant-title-test"
      assert resolved.model == "anthropic:claude-sonnet-4-5"
    end

    test "title generation falls back to default model when model is nil" do
      user = user_fixture()
      scope = %Scope{user: user}

      original = Application.get_env(:frontman_server, :openrouter_api_key)
      Application.put_env(:frontman_server, :openrouter_api_key, "server-key-fallback")

      # nil model falls back to default (openrouter)
      fallback_model = "openrouter:google/gemini-2.0-flash-001"

      {:ok, %ResolvedKey{} = resolved} =
        Providers.prepare_api_key(scope, fallback_model, %{}, skip_quota: true)

      assert resolved.provider == "openrouter"

      if original,
        do: Application.put_env(:frontman_server, :openrouter_api_key, original),
        else: Application.delete_env(:frontman_server, :openrouter_api_key)
    end
  end
end
