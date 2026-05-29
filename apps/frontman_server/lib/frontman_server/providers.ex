# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers do
  @moduledoc """
  The Providers context.

  Manages API keys and model provider access.

  ## API Key Resolution Flow

  The primary entry point for agent execution is `prepare_api_key/2`, which:
  1. Resolves the model to determine the provider
  2. Finds the best available API key (user key > env key > server key)
  3. Returns the key info for use in LLM calls
  """

  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Accounts],
    exports: [
      AnthropicOAuth,
      ChatGPTOAuth,
      Model,
      OAuthToken,
      Registry,
      ResolvedKey
    ]

  import Ecto.Query, warn: false
  alias FrontmanServer.Repo

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.{Scope, User}

  alias FrontmanServer.Providers.{
    AnthropicOAuth,
    ApiKey,
    ChatGPTOAuth,
    Model,
    ModelCatalog,
    OAuthToken,
    Registry,
    ResolvedKey
  }

  ## High-Level API (Domain Entry Points)

  @doc """
  Prepares API key for a request. Resolves model and key availability.

  This is the primary entry point for API key resolution at the domain layer.
  Call this before making LLM calls, not inside LLM implementations.

  ## Parameters
    - scope: The user scope (or nil for anonymous). Must have `env_api_keys`
      populated if project-level keys should be considered.
    - model: The model string (e.g., "openrouter:openai/gpt-4"), or nil for default

  ## Returns
    - `{:ok, ResolvedKey.t()}` - Ready to use for LLM calls
    - `{:error, :no_api_key}` - No API key available
  """
  @spec prepare_api_key(Accounts.scope() | nil, String.t() | nil) ::
          {:ok, ResolvedKey.t()} | {:error, :no_api_key}
  def prepare_api_key(scope, model) do
    model = model || default_model()
    provider = Model.provider_from_string(model)

    case resolve_api_key(scope, provider) do
      {:oauth_token, access_token, oauth_opts} ->
        {:ok, ResolvedKey.new(provider, access_token, :oauth_token, model, oauth_opts)}

      {:user_key, key} ->
        {:ok, ResolvedKey.new(provider, key, :user_key, model)}

      {:env_key, key} ->
        {:ok, ResolvedKey.new(provider, key, :env_key, model)}

      {:server_key, key} when is_binary(key) and key != "" ->
        {:ok, ResolvedKey.new(provider, key, :server_key, model)}

      {:server_key, _} ->
        {:error, :no_api_key}
    end
  end

  @spec default_model() :: String.t()
  defp default_model do
    case ModelCatalog.default_model("openrouter") do
      %{provider: provider, value: value} -> "#{provider}:#{value}"
      nil -> raise "missing default model for openrouter"
    end
  end

  @doc """
  Resolves a possibly nil model string to a concrete provider:model value.
  """
  @spec resolve_model_string(String.t() | nil) :: String.t() | nil
  defdelegate resolve_model_string(model), to: Model, as: :resolve_string

  @doc """
  Converts a resolved key into ReqLLM model + option arguments.
  """
  @spec to_llm_args(ResolvedKey.t(), keyword()) :: {String.t() | map(), keyword()}
  defdelegate to_llm_args(resolved_key), to: ResolvedKey
  defdelegate to_llm_args(resolved_key, opts), to: ResolvedKey

  @doc """
  Returns the provider-specific maximum image dimension when constrained.
  """
  @spec max_image_dimension(String.t()) :: pos_integer() | nil
  defdelegate max_image_dimension(provider), to: Registry

  @doc """
  Returns a human-friendly model name for logs and telemetry.
  """
  @spec display_model_name(map() | String.t() | nil) :: String.t()
  defdelegate display_model_name(model_ref), to: Model, as: :display_name

  @doc """
  Returns the provider name from a model reference.
  """
  @spec model_provider_name(map() | String.t() | nil) :: String.t()
  defdelegate model_provider_name(model_ref), to: Model, as: :provider_name

  @doc """
  Returns the underlying LLM vendor from a model reference.
  """
  @spec model_llm_vendor_name(map() | String.t() | nil) :: String.t()
  defdelegate model_llm_vendor_name(model_ref), to: Model, as: :llm_vendor_name

  ## API Key Management

  @doc """
  Stores or updates a user API key for a provider.

  On success, broadcasts a config change notification so subscribers
  (e.g. the tasks channel) can push updated config options to the client.
  """
  def upsert_api_key(%Scope{user: %User{} = user}, provider, key) do
    user_id = user.id
    provider = String.downcase(provider)
    # Build struct with user_id set explicitly (not via changeset for security)
    api_key = %ApiKey{user_id: user_id}
    changeset = ApiKey.changeset(api_key, %{provider: provider, key: key})

    case Repo.insert(
           changeset,
           on_conflict: {:replace, [:key, :updated_at]},
           conflict_target: [:user_id, :provider]
         ) do
      {:ok, record} ->
        broadcast_config_changed(user_id)
        {:ok, record}

      error ->
        error
    end
  end

  @doc """
  Lists providers with saved API keys for the user.
  """
  def list_api_key_providers(%Scope{user: %User{} = user}) do
    ApiKey
    |> ApiKey.for_user(user.id)
    |> order_by([key], asc: key.provider)
    |> select([key], key.provider)
    |> Repo.all()
  end

  @doc """
  Fetches a user API key for a provider.
  """
  def get_api_key(%Scope{user: %User{} = user}, provider) do
    ApiKey
    |> ApiKey.for_user_and_provider(user.id, provider)
    |> Repo.one()
  end

  ## API Key Resolution

  @doc """
  Resolves which API key to use for a provider.

  Resolution order:
  1. OAuth token (for supported providers)
  2. User's saved key
  3. Env key from `scope.env_api_keys` (e.g., OPENROUTER_API_KEY from project)
  4. Server env key (fallback)

  ## Parameters
    - scope: The user scope (or nil). env_api_keys are read from `scope.env_api_keys`.
    - provider: The provider name (e.g., "openrouter")
  """
  def resolve_api_key(scope, provider)

  def resolve_api_key(%Scope{} = scope, provider) when is_binary(provider) do
    case maybe_resolve_oauth_token(scope, provider) do
      {:oauth_token, _, _} = result ->
        result

      :no_oauth_token ->
        case get_api_key(scope, provider) do
          %ApiKey{key: key} when is_binary(key) and key != "" ->
            {:user_key, key}

          _ ->
            resolve_env_or_server_key(provider, Accounts.scope_env_api_keys(scope))
        end
    end
  end

  def resolve_api_key(nil, provider) when is_binary(provider) do
    resolve_env_or_server_key(provider, %{})
  end

  # Check for OAuth token - returns provider-specific transformation options
  defp maybe_resolve_oauth_token(scope, "anthropic") do
    case get_valid_oauth_token(scope, "anthropic") do
      {:ok, access_token} ->
        {:oauth_token, access_token, with_claude_subscription: true, auth_mode: :oauth}

      {:error, _} ->
        :no_oauth_token
    end
  end

  # ChatGPT OAuth: when user selects an openai: model AND has chatgpt oauth connected
  defp maybe_resolve_oauth_token(scope, "openai") do
    case get_valid_oauth_token(scope, "chatgpt") do
      {:ok, access_token} ->
        # Get account_id from stored token metadata
        account_id = get_chatgpt_account_id(scope)

        {:oauth_token, access_token,
         auth_mode: :oauth,
         chatgpt_account_id: account_id,
         codex_endpoint: "https://chatgpt.com/backend-api/codex/responses"}

      {:error, _} ->
        :no_oauth_token
    end
  end

  defp maybe_resolve_oauth_token(_scope, _provider), do: :no_oauth_token

  # Retrieve the chatgpt_account_id from stored token metadata
  defp get_chatgpt_account_id(scope) do
    case get_oauth_token(scope, "chatgpt") do
      %OAuthToken{metadata: %{"account_id" => account_id}} when is_binary(account_id) ->
        account_id

      _ ->
        nil
    end
  end

  # Check env key first, then fall back to server env key
  defp resolve_env_or_server_key(provider, env_api_key) when is_map(env_api_key) do
    case Map.get(env_api_key, provider) do
      key when is_binary(key) and key != "" -> {:env_key, key}
      _ -> {:server_key, get_server_api_key(provider)}
    end
  end

  @doc """
  Fetches a server API key for the provider from environment config.

  Delegates to `Registry.get_server_api_key/1`.
  """
  def get_server_api_key(provider) when is_binary(provider) do
    Registry.get_server_api_key(provider)
  end

  ## OAuth Token Management

  @doc """
  Stores or updates an OAuth token and broadcasts a config change.

  Use this for user-initiated OAuth connections (e.g. completing an OAuth flow).
  For internal token refreshes, use `upsert_oauth_token/6` directly.
  """
  def save_oauth_connection(
        %Scope{user: %User{} = user} = scope,
        provider,
        access_token,
        refresh_token,
        expires_at,
        metadata \\ %{}
      ) do
    user_id = user.id

    case upsert_oauth_token(scope, provider, access_token, refresh_token, expires_at, metadata) do
      {:ok, token} ->
        broadcast_config_changed(user_id)
        {:ok, token}

      error ->
        error
    end
  end

  @doc """
  Stores or updates an OAuth token for a provider.

  Does NOT broadcast config changes — use `save_oauth_connection/6` for
  user-initiated flows that should notify subscribers.

  Accepts an optional `metadata` map for provider-specific data (e.g., `account_id`).
  """
  def upsert_oauth_token(
        %Scope{user: %User{} = user},
        provider,
        access_token,
        refresh_token,
        expires_at,
        metadata \\ %{}
      ) do
    provider = String.downcase(provider)
    # Build struct with user_id set explicitly (not via changeset for security)
    oauth_token = %OAuthToken{user_id: user.id}

    changeset =
      OAuthToken.changeset(oauth_token, %{
        provider: provider,
        access_token: access_token,
        refresh_token: refresh_token,
        expires_at: expires_at,
        metadata: metadata
      })

    Repo.insert(
      changeset,
      on_conflict:
        {:replace, [:access_token, :refresh_token, :expires_at, :metadata, :updated_at]},
      conflict_target: [:user_id, :provider]
    )
  end

  @doc """
  Fetches an OAuth token for a provider (may be expired).
  """
  def get_oauth_token(%Scope{user: %User{} = user}, provider) do
    OAuthToken
    |> OAuthToken.for_user_and_provider(user.id, provider)
    |> Repo.one()
  end

  @doc """
  Returns true if the user has an OAuth token stored for the provider.
  """
  @spec has_oauth_token?(Scope.t(), String.t()) :: boolean()
  def has_oauth_token?(%Scope{} = scope, provider) do
    case get_oauth_token(scope, provider) do
      %OAuthToken{} -> true
      nil -> false
    end
  end

  @doc """
  Returns a valid (non-expired) OAuth access token, refreshing if needed.

  Returns `{:ok, access_token}` or `{:error, reason}`.
  """
  def get_valid_oauth_token(%Scope{} = scope, provider) do
    case get_oauth_token(scope, provider) do
      nil ->
        {:error, :no_oauth_token}

      %OAuthToken{} = token ->
        if OAuthToken.expired?(token) do
          refresh_oauth_token(scope, token)
        else
          {:ok, token.access_token}
        end
    end
  end

  @doc """
  Refreshes an OAuth token and updates the stored values.

  Dispatches to the correct provider's refresh_token implementation.
  Returns `{:ok, new_access_token}` or `{:error, reason}`.
  """
  def refresh_oauth_token(%Scope{} = scope, %OAuthToken{provider: "chatgpt"} = token) do
    case ChatGPTOAuth.refresh_token(token.refresh_token) do
      {:ok, new_tokens} ->
        expires_in = new_tokens.expires_in || 3600
        expires_at = OAuthToken.calculate_expires_at(expires_in)

        # Preserve existing metadata (account_id) when refreshing.
        # Metadata should always be a map (schema default is %{}), but guard against
        # nil from pre-migration rows that were never backfilled.
        metadata = if is_map(token.metadata), do: token.metadata, else: %{}

        case upsert_oauth_token(
               scope,
               "chatgpt",
               new_tokens.access_token,
               new_tokens.refresh_token || token.refresh_token,
               expires_at,
               metadata
             ) do
          {:ok, _} -> {:ok, new_tokens.access_token}
          {:error, reason} -> {:error, {:failed_to_store_refreshed_token, reason}}
        end

      {:error, reason} ->
        {:error, {:refresh_failed, reason}}
    end
  end

  def refresh_oauth_token(%Scope{} = scope, %OAuthToken{} = token) do
    case AnthropicOAuth.refresh_token(token.refresh_token) do
      {:ok, new_tokens} ->
        expires_at = AnthropicOAuth.calculate_expires_at(new_tokens.expires_in)

        case upsert_oauth_token(
               scope,
               token.provider,
               new_tokens.access_token,
               new_tokens.refresh_token,
               expires_at
             ) do
          {:ok, _} -> {:ok, new_tokens.access_token}
          {:error, reason} -> {:error, {:failed_to_store_refreshed_token, reason}}
        end

      {:error, reason} ->
        {:error, {:refresh_failed, reason}}
    end
  end

  @doc """
  Deletes an OAuth token for a provider.

  On success, broadcasts a config change notification so subscribers
  can push updated config options to the client.
  """
  def delete_oauth_token(%Scope{user: %User{} = user}, provider) do
    user_id = user.id
    query = OAuthToken.for_user_and_provider(OAuthToken, user_id, provider)

    case Repo.delete_all(query) do
      {0, _} ->
        {:error, :not_found}

      {_, _} ->
        broadcast_config_changed(user_id)
        :ok
    end
  end

  ## Config Change Notifications

  @doc """
  Returns the PubSub topic for config option updates for a given user.

  Subscribe to this topic to receive `:config_options_changed` messages
  when API keys or OAuth tokens are added/removed.
  """
  @spec config_pubsub_topic(String.t()) :: String.t()
  def config_pubsub_topic(user_id) when is_binary(user_id) do
    "config_update:user:#{user_id}"
  end

  @doc """
  Broadcasts a config options changed event for the given user.

  Called after API key saves or OAuth token changes so that subscribers
  (e.g. the tasks channel) can push updated config options to the client.
  """
  @spec broadcast_config_changed(String.t()) :: :ok | {:error, term()}
  def broadcast_config_changed(user_id) when is_binary(user_id) do
    Phoenix.PubSub.broadcast(
      FrontmanServer.PubSub,
      config_pubsub_topic(user_id),
      :config_options_changed
    )
  end

  ## Model Config (ACP-ready domain data)

  @doc """
  Returns model selection data for a user, ready for ACP serialization.

  Resolves which providers the user can access, at what tier, then builds
  model groups and picks the best default.  Returns a domain DTO that ACP
  translates to `SessionConfigOption` wire format.

  ## Parameters

    * `scope` – the user's `%Scope{}` struct. `env_api_keys` must be populated
      if project-level keys should be considered.

  ## Returns

  A map with:
    * `:groups` – list of model group maps, each with `:id`, `:name`, and
      `:options` (list of `%{name: String.t(), value: String.t()}` where
      `value` is a serialized `"provider:model"` string)
    * `:default_model` – serialized `"provider:model"` string for the best default
  """
  @spec model_config_data(Accounts.scope()) :: %{
          groups: [map()],
          default_model: String.t()
        }
  def model_config_data(scope) do
    provider_tiers = available_provider_tiers(scope)

    groups =
      Enum.map(provider_tiers, fn {provider, tier} ->
        group = ModelCatalog.model_group(provider, tier)

        options =
          Enum.map(group.models, fn model ->
            %{
              name: model.displayName,
              value: Model.new(provider, model.value) |> Model.to_string()
            }
          end)

        %{id: group.id, name: group.name, options: options}
      end)

    available_providers = Enum.map(provider_tiers, &elem(&1, 0))
    default = ModelCatalog.pick_default(available_providers)
    default_model = Model.new(default.provider, default.value) |> Model.to_string()

    %{groups: groups, default_model: default_model}
  end

  ## Provider Tier Resolution

  @doc """
  Resolves which providers a user can access and at what tier.

  Returns a list of `{provider_id, tier}` tuples sorted by provider
  priority.  Iterates all catalog providers and classifies each using
  `resolve_api_key/2`.

  ## Parameters

    * `scope` – the user's `%Scope{}` struct. `env_api_keys` must be populated
      if project-level keys should be considered.
  """
  @spec available_provider_tiers(Accounts.scope()) :: [{String.t(), :full | :free}]
  def available_provider_tiers(scope) do
    ModelCatalog.catalog_providers()
    |> Enum.flat_map(fn provider ->
      case {key_type(scope, provider), ModelCatalog.has_free_tier?(provider)} do
        {:own_key, _} -> [{provider, :full}]
        {:server_key, true} -> [{provider, :free}]
        {:server_key, false} -> []
        {:no_key, true} -> [{provider, :free}]
        {:no_key, false} -> []
      end
    end)
  end

  defp key_type(scope, provider) do
    case resolve_api_key(scope, provider) do
      {:oauth_token, _, _} -> :own_key
      {:user_key, _} -> :own_key
      {:env_key, _} -> :own_key
      {:server_key, key} when is_binary(key) and key != "" -> :server_key
      {:server_key, _} -> :no_key
    end
  end
end
