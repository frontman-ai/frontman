# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers do
  @moduledoc "Manages API keys, OAuth tokens, and model provider access."

  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Accounts]

  import Ecto.Query, warn: false
  alias FrontmanServer.Repo

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.{Scope, User}

  alias FrontmanServer.Providers.{
    AnthropicOAuth,
    ApiKey,
    OAuthToken,
    OpenAIOAuth
  }

  @providers Application.compile_env!(:frontman_server, :providers)
             |> Enum.map(fn {provider, config} -> {Atom.to_string(provider), config} end)

  @provider_configs Map.new(@providers)

  ## High-Level API (Domain Entry Points)

  @doc """
  Prepares ReqLLM arguments for a request. Resolves model and provider auth.

  This is the primary entry point for provider auth resolution at the domain layer.
  Call this before making LLM calls, not inside LLM implementations.

  ## Parameters
    - scope: The user scope (or nil for anonymous).
    - model: The model string (e.g., "openrouter:openai/gpt-4"), or nil for default

  ## Returns
    - `{:ok, {model_spec, llm_opts}}` - Ready to use for LLM calls
    - `{:error, :no_api_key}` - No API key available
  """
  def prepare_llm_args(scope, model, opts \\ []) do
    model = model || default_model()
    provider = model_provider_name(model)

    case oauth_llm_opts(provider, resolve_oauth_token(scope, provider)) do
      {:ok, llm_opts} -> {:ok, {model, Keyword.merge(llm_opts, opts)}}
      {:error, reason} -> {:error, reason}
      :use_api_key -> api_key_llm_args(scope, provider, model, opts)
    end
  end

  defp oauth_llm_opts("anthropic", %OAuthToken{access_token: access_token}) do
    {:ok,
     [
       auth_mode: :oauth,
       access_token: access_token,
       with_claude_subscription: true,
       anthropic_prompt_cache: true
     ]}
  end

  defp oauth_llm_opts(
         "openai_codex",
         %OAuthToken{access_token: access_token, metadata: %{"account_id" => account_id}}
       )
       when is_binary(account_id) and account_id != "" do
    {:ok, [auth_mode: :oauth, access_token: access_token, chatgpt_account_id: account_id]}
  end

  defp oauth_llm_opts("openai_codex", %OAuthToken{}), do: {:error, :invalid_oauth_token}
  defp oauth_llm_opts(_provider, _token), do: :use_api_key

  defp api_key_llm_args(scope, provider, model, opts) do
    case resolve_api_key(scope, provider) do
      key when is_binary(key) and key != "" ->
        {:ok, {model, Keyword.merge(api_key_llm_opts(provider, key), opts)}}

      _auth ->
        {:error, :no_api_key}
    end
  end

  defp api_key_llm_opts("anthropic", key), do: [api_key: key, anthropic_prompt_cache: true]
  defp api_key_llm_opts(_provider, key), do: [api_key: key]

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

  def connect_anthropic_oauth(%Scope{user: %User{} = user} = scope, code, verifier) do
    with {:ok, tokens} <- AnthropicOAuth.exchange_code(code, verifier),
         expires_at = OAuthToken.calculate_expires_at(tokens.expires_in),
         {:ok, _token} <-
           upsert_oauth_token(
             scope,
             "anthropic",
             tokens.access_token,
             tokens.refresh_token,
             expires_at
           ) do
      broadcast_config_changed(user.id)
      {:ok, expires_at}
    end
  end

  def start_openai_oauth, do: OpenAIOAuth.request_device_code()

  def poll_openai_oauth(scope, device_auth_id, user_code) do
    case OpenAIOAuth.poll_device_token(device_auth_id, user_code) do
      {:ok, %{authorization_code: authorization_code, code_verifier: code_verifier}} ->
        connect_openai_device_oauth(scope, authorization_code, code_verifier)

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

  defp connect_openai_device_oauth(
         %Scope{user: %User{} = user} = scope,
         authorization_code,
         code_verifier
       ) do
    with {:ok, tokens} <- OpenAIOAuth.exchange_device_code(authorization_code, code_verifier),
         account_id = OpenAIOAuth.extract_account_id_from_tokens(tokens),
         expires_at = OAuthToken.calculate_expires_at(tokens.expires_in),
         {:ok, _token} <-
           upsert_oauth_token(
             scope,
             "openai_codex",
             tokens.access_token,
             tokens.refresh_token,
             expires_at,
             %{"account_id" => account_id}
           ) do
      broadcast_config_changed(user.id)
      {:connected, expires_at}
    else
      {:error, reason} -> {:exchange_error, reason}
    end
  end

  @doc """
  Returns the provider-specific maximum image dimension when constrained.
  """
  def max_image_dimension(provider) when is_binary(provider) do
    provider_config(provider).max_image_dimension
  end

  @doc """
  Returns a human-friendly model name for logs and telemetry.
  """
  def display_model_name(model_ref) when is_binary(model_ref), do: model_ref
  def display_model_name(%{id: id}) when is_binary(id), do: id

  @doc """
  Returns the provider name from a model reference.
  """
  def model_provider_name(model_ref) when is_binary(model_ref) do
    {provider, _name} = model_parts(model_ref)
    provider
  end

  def model_provider_name(%{provider: provider}) when is_atom(provider),
    do: Atom.to_string(provider)

  @doc """
  Returns the underlying LLM vendor from a model reference.
  """
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

  defp get_api_key(%Scope{user: %User{} = user}, provider) do
    ApiKey
    |> ApiKey.for_user_and_provider(user.id, provider)
    |> Repo.one()
  end

  defp resolve_oauth_token(%Scope{} = scope, provider) do
    case get_oauth_token(scope, provider) do
      %OAuthToken{} = token ->
        if OAuthToken.expired?(token), do: refresh_oauth_token(scope, token), else: token

      nil ->
        nil
    end
  end

  defp resolve_oauth_token(_scope, _provider), do: nil

  defp resolve_api_key(%Scope{} = scope, provider) do
    case get_api_key(scope, provider) do
      %ApiKey{key: key} when is_binary(key) and key != "" ->
        key

      _ ->
        nil
    end
  end

  defp resolve_api_key(_scope, _provider), do: nil

  ## OAuth Token Management

  @doc "Stores or updates an OAuth token for a provider without broadcasting."
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

  defp refresh_oauth_token(%Scope{} = scope, %OAuthToken{provider: "openai_codex"} = token) do
    case OpenAIOAuth.refresh_token(token.refresh_token) do
      {:ok, new_tokens} ->
        expires_in = new_tokens.expires_in || 3600
        expires_at = OAuthToken.calculate_expires_at(expires_in)
        metadata = if is_map(token.metadata), do: token.metadata, else: %{}

        case upsert_oauth_token(
               scope,
               token.provider,
               new_tokens.access_token,
               new_tokens.refresh_token || token.refresh_token,
               expires_at,
               metadata
             ) do
          {:ok, token} -> token
          {:error, _reason} -> nil
        end

      {:error, _reason} ->
        nil
    end
  end

  defp refresh_oauth_token(%Scope{} = scope, %OAuthToken{} = token) do
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
          {:ok, token} -> token
          {:error, _reason} -> nil
        end

      {:error, _reason} ->
        nil
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
  def config_pubsub_topic(user_id) when is_binary(user_id) do
    "config_update:user:#{user_id}"
  end

  @doc """
  Broadcasts a config options changed event for the given user.

  Called after API key saves or OAuth token changes so that subscribers
  (e.g. the tasks channel) can push updated config options to the client.
  """
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

    * `scope` – the user's `%Scope{}` struct.

  ## Returns

  A map with:
    * `:groups` – list of model group maps, each with `:id`, `:name`, and
      `:options` (list of `%{name: name, value: value}` maps where
      `value` is a serialized `"provider:model"` string)
    * `:default_model` – serialized `"provider:model"` string for the best default
  """
  def model_config_data(scope) do
    api_key_providers = list_api_key_providers(scope)

    oauth_providers =
      OAuthToken
      |> OAuthToken.for_user(Accounts.scope_user_id(scope))
      |> select([token], token.provider)
      |> Repo.all()

    provider_configs =
      Enum.filter(@providers, fn
        {provider, %{models: [_ | _]}} ->
          provider in oauth_providers or provider in api_key_providers

        {_provider, _config} ->
          false
      end)

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
