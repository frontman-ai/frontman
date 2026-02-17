defmodule FrontmanServerWeb.ModelsController do
  @moduledoc """
  Returns available LLM models grouped by provider.

  Models are served dynamically based on the user's configured providers:
  - OpenRouter: Always available (server has API key)
  - Anthropic: Available when user has OAuth connected (Claude Pro/Max subscription)
  - OpenAI (ChatGPT): Available when user has ChatGPT OAuth connected (Pro/Plus subscription)
  """
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Providers

  # OpenRouter provider - full model list (when user has their own API key)
  @openrouter_provider %{
    id: "openrouter",
    name: "OpenRouter",
    models: [
      # OpenAI models
      %{displayName: "GPT-5.3 Codex", value: "openai/gpt-5.3-codex"},
      %{displayName: "GPT-5.2", value: "openai/gpt-5.2"},
      %{displayName: "GPT-5.1", value: "openai/gpt-5.1"},
      %{displayName: "GPT-5", value: "openai/gpt-5"},
      %{displayName: "GPT-5 mini", value: "openai/gpt-5-mini"},
      %{displayName: "GPT-5 Chat", value: "openai/gpt-5-chat"},
      %{displayName: "GPT-4.1", value: "openai/gpt-4.1"},
      %{displayName: "o3", value: "openai/o3"},
      %{displayName: "o4-mini", value: "openai/o4-mini"},
      # Anthropic models (via OpenRouter)
      %{displayName: "Claude Opus 4.6", value: "anthropic/claude-opus-4.6"},
      %{displayName: "Claude Sonnet 4.5", value: "anthropic/claude-sonnet-4.5"},
      %{displayName: "Claude Opus 4.5", value: "anthropic/claude-opus-4.5"},
      %{displayName: "Claude Haiku 4.5", value: "anthropic/claude-haiku-4.5"},
      # Google models
      %{displayName: "Gemini 3 Pro Preview", value: "google/gemini-3-pro-preview"},
      %{displayName: "Gemini 3 Flash Preview", value: "google/gemini-3-flash-preview"},
      %{displayName: "Gemini 2.5 Pro", value: "google/gemini-2.5-pro"}
    ]
  }

  # OpenRouter provider - free tier (no user/env key, limited server-key requests)
  @openrouter_free_provider %{
    id: "openrouter",
    name: "OpenRouter",
    models: [
      %{displayName: "Gemini 3 Flash", value: "google/gemini-3-flash-preview"},
      %{displayName: "Claude Haiku 4.5", value: "anthropic/claude-haiku-4.5"},
      %{displayName: "Kimi K2.5", value: "moonshotai/kimi-k2.5"},
      %{displayName: "Minimax M2.5", value: "minimax/minimax-m2.5"}
    ]
  }

  # Anthropic provider (direct API, requires OAuth)
  @anthropic_provider %{
    id: "anthropic",
    name: "Anthropic (Claude Pro/Max)",
    models: [
      %{displayName: "Claude Opus 4.6", value: "claude-opus-4-6"},
      %{displayName: "Claude Sonnet 4.5", value: "claude-sonnet-4-5"},
      %{displayName: "Claude Opus 4.5", value: "claude-opus-4-5"},
      %{displayName: "Claude Haiku 4.5", value: "claude-haiku-4-5"},
      %{displayName: "Claude Sonnet 4", value: "claude-sonnet-4-20250514"},
      %{displayName: "Claude Opus 4", value: "claude-opus-4-20250514"}
    ]
  }

  # OpenAI (ChatGPT Pro/Plus) provider - requires ChatGPT OAuth
  @openai_provider %{
    id: "openai",
    name: "ChatGPT Pro/Plus",
    models: [
      %{displayName: "GPT-5.3 Codex", value: "gpt-5.3-codex"},
      %{displayName: "GPT-5.2 Codex", value: "gpt-5.2-codex"},
      %{displayName: "GPT-5.2", value: "gpt-5.2"},
      %{displayName: "GPT-5.1 Codex Max", value: "gpt-5.1-codex-max"},
      %{displayName: "GPT-5.1 Codex Mini", value: "gpt-5.1-codex-mini"}
    ]
  }

  # Default models for each scenario
  @openrouter_default %{provider: "openrouter", value: "google/gemini-3-flash-preview"}
  @anthropic_default %{provider: "anthropic", value: "claude-sonnet-4-5"}
  @openai_default %{provider: "openai", value: "gpt-5.1-codex-max"}

  @doc """
  Returns the available models configuration.

  GET /api/models

  The response includes providers based on user's configuration:
  - OpenRouter: Always included
  - Anthropic: Included when user has OAuth connected

  Response:
  {
    "providers": [...],
    "defaultModel": {"provider": "...", "value": "..."}
  }
  """
  def index(conn, params) do
    scope = conn.assigns.current_scope

    has_anthropic_oauth = Providers.has_oauth_token?(scope, "anthropic")
    has_chatgpt_oauth = Providers.has_oauth_token?(scope, "chatgpt")

    # Determine if user has their own OpenRouter key (user-stored or from env)
    has_user_key = Providers.has_api_key?(scope, "openrouter")
    has_env_key = params["hasEnvKey"] == "true"
    has_openrouter_key = has_user_key or has_env_key

    # Show full model list when user has their own key, free tier otherwise
    openrouter = if has_openrouter_key, do: @openrouter_provider, else: @openrouter_free_provider

    # Build providers list: OAuth providers first (if available), then OpenRouter
    providers =
      []
      |> then(fn list -> if has_chatgpt_oauth, do: list ++ [@openai_provider], else: list end)
      |> then(fn list ->
        if has_anthropic_oauth, do: list ++ [@anthropic_provider], else: list
      end)
      |> Kernel.++([openrouter])

    # Default model priority: ChatGPT > Anthropic > OpenRouter
    default_model =
      cond do
        has_chatgpt_oauth -> @openai_default
        has_anthropic_oauth -> @anthropic_default
        true -> @openrouter_default
      end

    json(conn, %{providers: providers, defaultModel: default_model})
  end
end
