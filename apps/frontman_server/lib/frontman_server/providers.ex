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
  2. Finds the best available API key (OAuth > user key > env key)
  3. Returns the key info for use in LLM calls
  """

  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Accounts]

  import Ecto.Query, warn: false
  alias FrontmanServer.Repo

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.{Scope, User}

  alias FrontmanServer.Providers.{
    AnthropicOAuth,
    ApiKey,
    ChatGPTOAuth,
    OAuthToken,
    ResolvedKey
  }

  @providers Application.compile_env!(:frontman_server, :providers)
             |> Enum.map(fn {provider, config} -> {Atom.to_string(provider), config} end)

  @provider_configs Map.new(@providers)
  @codex_base_url "https://chatgpt.com/backend-api/codex"

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
    provider = model_provider_name(model)

    case resolve_oauth_key(scope, provider, model) do
      {:ok, resolved_key} ->
        {:ok, resolved_key}

      :no_oauth_token ->
        case resolve_api_key(scope, provider) do
          {:user_key, key} ->
            {:ok, %ResolvedKey{provider: provider, model: model, llm_opts: [api_key: key]}}

          {:env_key, key} ->
            {:ok, %ResolvedKey{provider: provider, model: model, llm_opts: [api_key: key]}}

          :no_api_key ->
            {:error, :no_api_key}
        end
    end
  end

  @doc """
  Converts a resolved key into ReqLLM model + option arguments.
  """
  @spec to_llm_args(ResolvedKey.t(), keyword()) :: {String.t() | map(), keyword()}
  defdelegate to_llm_args(resolved_key), to: ResolvedKey
  defdelegate to_llm_args(resolved_key, opts), to: ResolvedKey

  def model_from_client_params(nil), do: :error

  def model_from_client_params(%{"provider" => provider, "value" => value})
      when is_binary(provider) and is_binary(value) and provider != "" and value != "" do
    {:ok, model_string(provider, value)}
  end

  def model_from_client_params(params) do
    {provider, name} = model_parts(params)
    {:ok, model_string(provider, name)}
  end

  def start_anthropic_oauth do
    {verifier, challenge} = AnthropicOAuth.generate_pkce()

    %{
      authorize_url: AnthropicOAuth.build_authorize_url(challenge, verifier),
      verifier: verifier
    }
  end

  def connect_anthropic_oauth(scope, code, verifier) do
    with {:ok, tokens} <- AnthropicOAuth.exchange_code(code, verifier),
         expires_at = OAuthToken.calculate_expires_at(tokens.expires_in),
         {:ok, _token} <-
           save_oauth_connection(
             scope,
             "anthropic",
             tokens.access_token,
             tokens.refresh_token,
             expires_at
           ) do
      {:ok, expires_at}
    end
  end

  def start_chatgpt_oauth do
    with {:ok, %{device_auth_id: device_auth_id, user_code: user_code}} <-
           ChatGPTOAuth.request_device_code() do
      {:ok,
       %{
         device_auth_id: device_auth_id,
         user_code: user_code,
         verification_url: ChatGPTOAuth.verification_url()
       }}
    end
  end

  def poll_chatgpt_oauth(scope, device_auth_id, user_code) do
    case ChatGPTOAuth.poll_device_token(device_auth_id, user_code) do
      {:ok, %{authorization_code: authorization_code, code_verifier: code_verifier}} ->
        connect_chatgpt_device_oauth(scope, authorization_code, code_verifier)

      result ->
        result
    end
  end

  def oauth_connection_status(scope, provider) do
    case get_oauth_token(scope, provider) do
      nil ->
        %{connected: false}

      token ->
        %{
          connected: true,
          expires_at: DateTime.to_iso8601(token.expires_at),
          expired: OAuthToken.expired?(token)
        }
    end
  end

  defp connect_chatgpt_device_oauth(scope, authorization_code, code_verifier) do
    with {:ok, tokens} <- ChatGPTOAuth.exchange_device_code(authorization_code, code_verifier),
         account_id = ChatGPTOAuth.extract_account_id_from_tokens(tokens),
         expires_at = OAuthToken.calculate_expires_at(tokens.expires_in),
         {:ok, _token} <-
           save_oauth_connection(
             scope,
             "chatgpt",
             tokens.access_token,
             tokens.refresh_token,
             expires_at,
             %{"account_id" => account_id}
           ) do
      {:connected, expires_at}
    else
      {:error, reason} -> {:exchange_error, reason}
    end
  end

  @doc """
  Returns the provider-specific maximum image dimension when constrained.
  """
  @spec max_image_dimension(String.t()) :: pos_integer() | nil
  def max_image_dimension(provider) when is_binary(provider) do
    provider_config(provider).max_image_dimension
  end

  @doc """
  Extracts provider API keys from a metadata map sent by the client.
  """
  @spec extract_env_keys(map()) :: %{String.t() => String.t()}
  def extract_env_keys(metadata) when is_map(metadata) do
    nested_keys =
      case metadata["envApiKey"] do
        env_api_key when is_map(env_api_key) -> extract_env_keys(env_api_key)
        _ -> %{}
      end

    top_level_keys =
      for {provider, %{env_key_name: name}} when is_binary(name) <- @providers,
          key = metadata[name],
          is_binary(key) and key != "",
          into: %{} do
        {provider, key}
      end

    Map.merge(top_level_keys, nested_keys)
  end

  @doc """
  Returns a human-friendly model name for logs and telemetry.
  """
  @spec display_model_name(map() | String.t()) :: String.t()
  def display_model_name(model_ref) when is_binary(model_ref), do: model_ref
  def display_model_name(%{id: id}) when is_binary(id), do: id

  @doc """
  Returns the provider name from a model reference.
  """
  @spec model_provider_name(map() | String.t()) :: String.t()
  def model_provider_name(model_ref) when is_binary(model_ref) do
    {provider, _name} = model_parts(model_ref)
    provider
  end

  def model_provider_name(%{provider: provider}) when is_atom(provider),
    do: Atom.to_string(provider)

  @doc """
  Returns the underlying LLM vendor from a model reference.
  """
  @spec model_llm_vendor_name(map() | String.t()) :: String.t()
  def model_llm_vendor_name(model_ref) when is_binary(model_ref) do
    {provider, name} = model_parts(model_ref)
    llm_vendor_name(provider, name)
  end

  def model_llm_vendor_name(%{provider: :openrouter, id: id}) when is_binary(id) do
    openrouter_vendor_name(id)
  end

  def model_llm_vendor_name(%{provider: provider}) when is_atom(provider),
    do: Atom.to_string(provider)

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

  defp resolve_api_key(%Scope{} = scope, provider) when is_binary(provider) do
    case get_api_key(scope, provider) do
      %ApiKey{key: key} when is_binary(key) and key != "" ->
        {:user_key, key}

      _ ->
        resolve_env_key(provider, Accounts.scope_env_api_keys(scope))
    end
  end

  defp resolve_api_key(nil, provider) when is_binary(provider), do: :no_api_key

  defp resolve_oauth_key(nil, _provider, _model), do: :no_oauth_token

  defp resolve_oauth_key(scope, "anthropic", model) do
    case get_valid_oauth_token(scope, "anthropic") do
      {:ok, access_token} ->
        {:ok,
         %ResolvedKey{
           provider: "anthropic",
           model: model,
           llm_opts: [
             auth_mode: :oauth,
             access_token: access_token,
             with_claude_subscription: true
           ]
         }}

      {:error, _} ->
        :no_oauth_token
    end
  end

  defp resolve_oauth_key(scope, "openai", model) do
    case get_valid_oauth_token(scope, "chatgpt") do
      {:ok, access_token} ->
        account_id = get_chatgpt_account_id(scope)

        {:ok,
         %ResolvedKey{
           provider: "openai",
           model: codex_model(model),
           llm_opts: [
             auth_mode: :oauth,
             access_token: access_token,
             base_url: @codex_base_url,
             chatgpt_account_id: account_id
           ]
         }}

      {:error, _} ->
        :no_oauth_token
    end
  end

  defp resolve_oauth_key(_scope, _provider, _model), do: :no_oauth_token

  defp oauth_key?(nil, _provider), do: false

  defp oauth_key?(scope, "anthropic"),
    do: match?({:ok, _}, get_valid_oauth_token(scope, "anthropic"))

  defp oauth_key?(scope, "openai"), do: match?({:ok, _}, get_valid_oauth_token(scope, "chatgpt"))
  defp oauth_key?(_scope, _provider), do: false

  # Retrieve the chatgpt_account_id from stored token metadata
  defp get_chatgpt_account_id(scope) do
    %OAuthToken{metadata: %{"account_id" => account_id}} = get_oauth_token(scope, "chatgpt")
    account_id
  end

  defp resolve_env_key(provider, env_api_key) when is_map(env_api_key) do
    case Map.get(env_api_key, provider) do
      key when is_binary(key) and key != "" -> {:env_key, key}
      _ -> :no_api_key
    end
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
        expires_at = OAuthToken.calculate_expires_at(new_tokens.expires_in)

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

  Resolves which providers the user can access, then builds model groups and
  picks the best default. Returns a domain DTO that ACP
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
    provider_configs = available_provider_configs(scope)

    groups =
      Enum.map(provider_configs, fn {provider, config} ->
        options =
          config.models
          |> Enum.map(fn {name, value, _llm_db} ->
            %{
              name: name,
              value: model_string(provider, value)
            }
          end)

        %{id: provider, name: config.display_name, options: options}
      end)

    default_model = pick_default_model(provider_configs)

    %{groups: groups, default_model: default_model}
  end

  ## Provider Access Resolution

  defp available_provider_configs(scope) do
    @providers
    |> Enum.filter(fn
      {provider, %{models: [_ | _]}} -> own_key?(scope, provider)
      {_provider, _config} -> false
    end)
  end

  defp provider_config(provider) do
    Map.fetch!(@provider_configs, String.downcase(provider))
  end

  defp default_model do
    default_model_for("openrouter", provider_config("openrouter"))
  end

  defp default_model_for(provider, config) do
    model_string(String.downcase(provider), config.default_model)
  end

  defp pick_default_model([]) do
    default_model_for("openrouter", provider_config("openrouter"))
  end

  defp pick_default_model(provider_configs) do
    [{provider, config} | _] = provider_configs
    default_model_for(provider, config)
  end

  defp own_key?(scope, provider) do
    case {oauth_key?(scope, provider), resolve_api_key(scope, provider)} do
      {true, _} -> true
      {false, {:user_key, _}} -> true
      {false, {:env_key, _}} -> true
      {false, :no_api_key} -> false
    end
  end

  defp codex_model("openai:codex-5.3"), do: resolve_codex_model("openai_codex:gpt-5.3-codex")
  defp codex_model("openai:" <> model_id), do: resolve_codex_model("openai_codex:" <> model_id)

  defp resolve_codex_model(model_string) do
    {:ok, model} = ReqLLM.model(model_string)
    model
  end

  defp model_parts(model) when is_binary(model) do
    case String.split(model, ":", parts: 2) do
      [provider, name] when provider != "" and name != "" -> {provider, name}
    end
  end

  defp model_string(provider, name), do: "#{provider}:#{name}"

  defp llm_vendor_name("openrouter", name), do: openrouter_vendor_name(name)
  defp llm_vendor_name(provider, _name), do: provider

  defp openrouter_vendor_name(name) do
    case String.split(name, "/", parts: 2) do
      [vendor, _rest] when vendor != "" -> vendor
    end
  end
end
