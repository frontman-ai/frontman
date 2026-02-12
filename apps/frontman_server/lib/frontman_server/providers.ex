defmodule FrontmanServer.Providers do
  @moduledoc """
  The Providers context.

  Manages API keys and usage tracking for LLM providers.

  ## API Key Resolution Flow

  The primary entry point for agent execution is `prepare_api_key/3`, which:
  1. Resolves the model to determine the provider
  2. Finds the best available API key (user key > env key > server key)
  3. Checks usage quota for server keys
  4. Returns the key info for use in LLM calls

  After a successful agent run, call `record_usage/3` to track server key usage.
  """

  import Ecto.Query, warn: false
  alias FrontmanServer.Repo

  alias FrontmanServer.Accounts.{Scope, User}

  alias FrontmanServer.Providers.{
    AnthropicOAuth,
    ApiKey,
    ChatGPTOAuth,
    OAuthToken,
    ResolvedKey,
    UserKeyUsage
  }

  @default_model "openrouter:openai/gpt-5.1-codex"

  ## High-Level API (Domain Entry Points)

  @doc """
  Returns the default model.
  """
  def default_model, do: @default_model

  @doc """
  Prepares API key for a request. Resolves model, checks availability and quota.
  Does NOT track usage - call `record_usage/1` after successful LLM response.

  This is the primary entry point for API key resolution at the domain layer.
  Call this before making LLM calls, not inside LLM implementations.

  ## Parameters
    - scope: The user scope (or nil for anonymous)
    - model: The model string (e.g., "openrouter:openai/gpt-4"), or nil for default
    - env_api_key: Map of provider => api_key from client's environment

  ## Returns
    - `{:ok, ResolvedKey.t()}` - Ready to use for LLM calls
    - `{:error, :no_api_key}` - No API key available
    - `{:error, :usage_limit_exceeded}` - Server key quota exhausted
  """
  @spec prepare_api_key(Scope.t() | nil, String.t() | nil, map()) ::
          {:ok, ResolvedKey.t()} | {:error, :no_api_key | :usage_limit_exceeded}
  def prepare_api_key(scope, model, env_api_key \\ %{}) do
    model = model || @default_model
    provider = provider_from_model(model)

    case resolve_api_key(scope, provider, env_api_key) do
      {:oauth_token, access_token, oauth_opts} ->
        {:ok, ResolvedKey.new(provider, access_token, :oauth_token, model, oauth_opts)}

      {:user_key, key} ->
        {:ok, ResolvedKey.new(provider, key, :user_key, model)}

      {:env_key, key} ->
        {:ok, ResolvedKey.new(provider, key, :env_key, model)}

      {:server_key, key} ->
        prepare_server_key(scope, provider, key, model)
    end
  end

  defp prepare_server_key(_scope, _provider, key, _model) when not is_binary(key) or key == "" do
    {:error, :no_api_key}
  end

  defp prepare_server_key(nil, provider, key, model) do
    {:ok, ResolvedKey.new(provider, key, :server_key, model)}
  end

  defp prepare_server_key(scope, provider, key, model) do
    if has_remaining_usage?(scope, provider) do
      {:ok, ResolvedKey.new(provider, key, :server_key, model)}
    else
      {:error, :usage_limit_exceeded}
    end
  end

  @doc """
  Records successful API key usage. Call this after a successful agent run.
  Only increments usage for server keys.

  ## Parameters
    - scope: The user scope (or nil)
    - resolved_key: The ResolvedKey struct from prepare_api_key/3
  """
  @spec record_usage(Scope.t() | nil, ResolvedKey.t()) :: :ok | {:error, term()}
  def record_usage(nil, %ResolvedKey{}), do: :ok
  def record_usage(_scope, %ResolvedKey{key_source: :user_key}), do: :ok
  def record_usage(_scope, %ResolvedKey{key_source: :env_key}), do: :ok
  def record_usage(_scope, %ResolvedKey{key_source: :oauth_token}), do: :ok

  def record_usage(%Scope{} = scope, %ResolvedKey{key_source: :server_key, provider: provider}) do
    case increment_usage(scope, provider) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Extracts provider name from model string.
  """
  @spec provider_from_model(String.t()) :: String.t()
  def provider_from_model(model) when is_binary(model) do
    cond do
      String.starts_with?(model, "openrouter:") -> "openrouter"
      String.starts_with?(model, "anthropic:") -> "anthropic"
      String.starts_with?(model, "google:") -> "google"
      String.starts_with?(model, "openai:") -> "openai"
      true -> "openrouter"
    end
  end

  ## API Key Management

  @doc """
  Stores or updates a user API key for a provider.
  """
  def upsert_api_key(%Scope{user: %User{} = user}, provider, key) do
    provider = String.downcase(provider)
    # Build struct with user_id set explicitly (not via changeset for security)
    api_key = %ApiKey{user_id: user.id}
    changeset = ApiKey.changeset(api_key, %{provider: provider, key: key})

    Repo.insert(
      changeset,
      on_conflict: {:replace, [:key, :updated_at]},
      conflict_target: [:user_id, :provider]
    )
  end

  @doc """
  Fetches a user API key for a provider.
  """
  def get_api_key(%Scope{user: %User{} = user}, provider) do
    ApiKey
    |> ApiKey.for_user_and_provider(user.id, provider)
    |> Repo.one()
  end

  @doc """
  Returns the user's API key value for a provider, if present.
  """
  def get_api_key_value(%Scope{} = scope, provider) do
    case get_api_key(scope, provider) do
      %ApiKey{key: key} -> key
      _ -> nil
    end
  end

  @doc """
  Returns true if the user has a stored API key for the provider.
  """
  def has_api_key?(%Scope{} = scope, provider) do
    case get_api_key(scope, provider) do
      %ApiKey{} -> true
      _ -> false
    end
  end

  ## Usage Tracking

  @doc """
  Returns the server key usage limit from config.
  """
  def usage_limit do
    Application.get_env(:frontman_server, :user_key_usage_limit, 10)
  end

  @doc """
  Returns the user key usage record if it exists.
  """
  def get_usage(%Scope{user: %User{} = user}, provider) do
    Repo.get_by(UserKeyUsage, user_id: user.id, provider: provider)
  end

  @doc """
  Returns the remaining server-key requests for the user and provider.
  """
  def get_usage_remaining(%Scope{} = scope, provider) do
    case get_usage(scope, provider) do
      %UserKeyUsage{count: count} -> max(usage_limit() - count, 0)
      nil -> usage_limit()
    end
  end

  @doc """
  Returns true if the user has remaining server-key requests.
  """
  def has_remaining_usage?(%Scope{} = scope, provider) do
    get_usage_remaining(scope, provider) > 0
  end

  @doc """
  Returns usage details for the user's server key usage.
  """
  def get_usage_status(%Scope{} = scope, provider) do
    limit = usage_limit()
    used = usage_count(get_usage(scope, provider))
    remaining = max(limit - used, 0)

    %{
      limit: limit,
      used: used,
      remaining: remaining,
      has_user_key: has_api_key?(scope, provider),
      has_server_key: is_binary(get_server_api_key(provider))
    }
  end

  defp usage_count(nil), do: 0
  defp usage_count(%UserKeyUsage{count: count}) when is_integer(count), do: count

  @doc """
  Increments the user's server-key usage count.
  """
  def increment_usage(%Scope{user: %User{} = user}, provider) do
    case get_usage(%Scope{user: user}, provider) do
      nil ->
        # Build struct with user_id set explicitly (not via changeset for security)
        usage = %UserKeyUsage{user_id: user.id}
        changeset = UserKeyUsage.changeset(usage, %{count: 1, provider: provider})
        Repo.insert(changeset)

      %UserKeyUsage{} = usage ->
        usage
        |> UserKeyUsage.increment_changeset()
        |> Repo.update()
    end
  end

  ## API Key Resolution

  @doc """
  Resolves which API key to use for a provider.

  Resolution order:
  1. User's saved key (highest priority)
  2. Env key from the project (e.g., Next.js OPENROUTER_API_KEY)
  3. Server env key (fallback)

  ## Parameters
    - scope: The user scope (or nil)
    - provider: The provider name (e.g., "openrouter")
    - env_api_key: Map of provider => api_key from client's environment (or %{})
  """
  def resolve_api_key(scope, provider, env_api_key \\ %{})

  def resolve_api_key(%Scope{} = scope, provider, env_api_key)
      when is_binary(provider) and is_map(env_api_key) do
    # For Anthropic, check OAuth token first (highest priority)
    case maybe_resolve_oauth_token(scope, provider) do
      {:oauth_token, _, _} = result ->
        result

      :no_oauth_token ->
        # Then check user's saved API key
        case get_api_key_value(scope, provider) do
          key when is_binary(key) and key != "" ->
            {:user_key, key}

          _ ->
            # Then check env key (from project environment)
            resolve_env_or_server_key(provider, env_api_key)
        end
    end
  end

  def resolve_api_key(nil, provider, env_api_key)
      when is_binary(provider) and is_map(env_api_key) do
    resolve_env_or_server_key(provider, env_api_key)
  end

  # Claude Code identity for Anthropic OAuth
  @claude_code_identity "You are Claude Code, Anthropic's official CLI for Claude."

  # Check for OAuth token - returns provider-specific transformation options
  defp maybe_resolve_oauth_token(scope, "anthropic") do
    case get_valid_oauth_token(scope, "anthropic") do
      {:ok, access_token} ->
        {:oauth_token, access_token,
         requires_mcp_prefix: true, identity_override: @claude_code_identity, oauth_mode: true}

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
         oauth_mode: true,
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
  """
  def get_server_api_key(provider) when is_binary(provider) do
    provider = String.downcase(provider)

    case provider do
      "openrouter" -> Application.get_env(:frontman_server, :openrouter_api_key)
      "anthropic" -> Application.get_env(:frontman_server, :anthropic_api_key)
      "google" -> Application.get_env(:frontman_server, :google_api_key)
      "openai" -> Application.get_env(:frontman_server, :openai_api_key)
      _ -> nil
    end
  end

  ## OAuth Token Management

  @doc """
  Stores or updates an OAuth token for a provider.

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
  """
  def delete_oauth_token(%Scope{user: %User{} = user}, provider) do
    query = OAuthToken.for_user_and_provider(OAuthToken, user.id, provider)

    case Repo.delete_all(query) do
      {0, _} -> {:error, :not_found}
      {_, _} -> :ok
    end
  end
end
