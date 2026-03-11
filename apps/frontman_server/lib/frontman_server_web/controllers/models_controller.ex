defmodule FrontmanServerWeb.ModelsController do
  @moduledoc """
  Returns available LLM models grouped by provider.

  Models are served dynamically based on the user's configured providers.
  Provider metadata (display names, priorities, OAuth mapping) comes from
  `Providers.Registry`; model lists and defaults come from
  `Providers.ModelCatalog`.
  """
  use FrontmanServerWeb, :controller

  alias FrontmanServer.Providers
  alias FrontmanServer.Providers.{ModelCatalog, Registry}

  # Providers the catalog exposes to the client, in priority order.
  # OpenRouter is always included (server has a fallback key).
  @optional_providers ["openai", "anthropic"]

  @doc """
  Returns the available models configuration.

  GET /api/models

  The response includes providers based on user's configuration:
  - OpenAI (ChatGPT): Included when user has ChatGPT OAuth connected
  - Anthropic: Included when user has OAuth, a stored API key, or an env key
  - OpenRouter: Always included (full list when user has key, free tier otherwise)

  Response:
  {
    "providers": [...],
    "defaultModel": {"provider": "...", "value": "..."}
  }
  """
  def index(conn, params) do
    scope = conn.assigns.current_scope

    # Determine which optional providers the user can access
    accessible =
      @optional_providers
      |> Enum.filter(&has_access?(scope, &1, params))

    # OpenRouter tier depends on whether the user has their own key
    openrouter_tier = if has_access?(scope, "openrouter", params), do: :full, else: :free

    # Build provider list: accessible optional providers + OpenRouter (always last by priority)
    providers =
      (accessible |> Enum.map(&ModelCatalog.provider_entry(&1, :full))) ++
        [ModelCatalog.provider_entry("openrouter", openrouter_tier)]

    # Pick the best default from all accessible providers (including OpenRouter)
    default_model = ModelCatalog.pick_default(accessible ++ ["openrouter"])

    json(conn, %{providers: providers, defaultModel: default_model})
  end

  # Unified access check: does the user have an OAuth token, stored API key,
  # or client-forwarded env key for this provider?
  defp has_access?(scope, provider, params) do
    has_oauth?(scope, provider) or
      Providers.has_api_key?(scope, provider) or
      has_env_key_param?(provider, params)
  end

  defp has_oauth?(scope, provider) do
    case Registry.oauth_provider(provider) do
      nil -> false
      oauth_id -> Providers.has_oauth_token?(scope, oauth_id)
    end
  end

  defp has_env_key_param?(provider, params) do
    case Registry.env_key_param(provider) do
      nil -> false
      param -> params[param] == "true"
    end
  end
end
