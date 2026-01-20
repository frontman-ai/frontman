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
  alias FrontmanServer.Providers.{ApiKey, ResolvedKey, UserKeyUsage}

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
      {:user_key, key} ->
        {:ok, ResolvedKey.new(provider, key, :user_key, model)}

      {:env_key, key} ->
        {:ok, ResolvedKey.new(provider, key, :env_key, model)}

      {:server_key, key} when is_binary(key) and key != "" ->
        if scope == nil or has_remaining_usage?(scope, provider) do
          {:ok, ResolvedKey.new(provider, key, :server_key, model)}
        else
          {:error, :usage_limit_exceeded}
        end

      {:server_key, _} ->
        {:error, :no_api_key}
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
    # First check user's saved key
    case get_api_key_value(scope, provider) do
      key when is_binary(key) and key != "" ->
        {:user_key, key}

      _ ->
        # Then check env key (from project environment)
        resolve_env_or_server_key(provider, env_api_key)
    end
  end

  def resolve_api_key(nil, provider, env_api_key)
      when is_binary(provider) and is_map(env_api_key) do
    resolve_env_or_server_key(provider, env_api_key)
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
end
