# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers do
  @moduledoc "Manages API keys, OAuth tokens, and model provider access."

  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Accounts]

  alias FrontmanServer.{PublicURL, Repo}

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.{Scope, User}

  alias FrontmanServer.Providers.{
    AnthropicOAuth,
    ApiKey,
    CustomProvider,
    CustomProviderModel,
    OAuthToken,
    OpenAIOAuth
  }

  def list_custom_providers(%Scope{user: %User{id: user_id}}) do
    CustomProvider
    |> CustomProvider.for_user(user_id)
    |> Repo.all()
    |> Repo.preload(models: CustomProviderModel.ordered())
    |> Enum.map(&custom_provider_data/1)
  end

  def create_custom_provider(%Scope{user: %User{id: user_id}}, attrs) do
    %CustomProvider{user_id: user_id}
    |> CustomProvider.changeset(attrs)
    |> Repo.insert()
    |> custom_provider_result()
  end

  def update_custom_provider(%Scope{user: %User{}} = scope, id, attrs) do
    case get_owned_custom_provider(scope, id) do
      %CustomProvider{} = provider ->
        provider
        |> CustomProvider.changeset(attrs)
        |> Repo.update()
        |> custom_provider_result()

      nil ->
        {:error, :not_found}
    end
  end

  def delete_custom_provider(%Scope{user: %User{}} = scope, id) do
    case get_owned_custom_provider(scope, id) do
      %CustomProvider{} = provider ->
        Repo.delete!(provider)
        :ok

      nil ->
        {:error, :not_found}
    end
  end

  def add_custom_provider_model(%Scope{user: %User{}} = scope, custom_provider_id, attrs) do
    case get_owned_custom_provider(scope, custom_provider_id) do
      %CustomProvider{} = provider ->
        case %CustomProviderModel{custom_provider_id: custom_provider_id}
             |> CustomProviderModel.changeset(attrs)
             |> Repo.insert() do
          {:ok, _model} -> custom_provider_result({:ok, provider})
          {:error, changeset} -> {:error, validation_errors(changeset)}
        end

      nil ->
        {:error, :not_found}
    end
  end

  def remove_custom_provider_model(
        %Scope{user: %User{}} = scope,
        custom_provider_id,
        provider_model_id
      ) do
    with {:ok, provider_model_id} <- Ecto.UUID.cast(provider_model_id),
         %CustomProvider{} = provider <- get_owned_custom_provider(scope, custom_provider_id),
         %CustomProviderModel{} = model <-
           Repo.get_by(CustomProviderModel,
             id: provider_model_id,
             custom_provider_id: custom_provider_id
           ) do
      {:ok, _model} = Repo.delete(model)
      custom_provider_result({:ok, provider})
    else
      :error -> {:error, :not_found}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Prepares ReqLLM arguments for a request. Resolves model and provider auth.

  This is the primary entry point for provider auth resolution at the domain layer.
  Call this before making LLM calls, not inside LLM implementations.

  ## Parameters
    - scope: The user scope (or nil for anonymous).
    - model: The model string (e.g., "openrouter:openai/gpt-4")

  ## Returns
    - `{:ok, {model_spec, llm_opts}}` - Ready to use for LLM calls
    - `{:error, :no_api_key}` - No API key available
  """
  def prepare_llm_args(scope, model, opts \\ [])

  def prepare_llm_args(_scope, nil, _opts), do: {:error, :missing_model}

  def prepare_llm_args(scope, "custom:" <> rest, opts) when is_binary(rest) and rest != "" do
    case String.split(rest, ":", parts: 2) do
      [provider_id, model_id] when provider_id != "" and model_id != "" ->
        resolve_custom_model(scope, provider_id, model_id, opts)

      _ ->
        {:error, :unknown_model}
    end
  end

  def prepare_llm_args(scope, model, opts) when is_binary(model) and model != "" do
    with {:ok, {credential_source, resolved_model}} <- resolve_catalog_model(model) do
      case oauth_llm_opts(credential_source, resolve_oauth_token(scope, credential_source)) do
        {:ok, llm_opts} ->
          {:ok,
           {resolved_model, Keyword.merge(llm_opts ++ transport_llm_opts(resolved_model), opts)}}

        {:error, reason} ->
          {:error, reason}

        :use_api_key ->
          api_key_llm_args(scope, credential_source, resolved_model, opts)
      end
    end
  end

  def prepare_llm_args(_scope, _model, _opts), do: {:error, :missing_model}

  defp oauth_llm_opts("anthropic", %OAuthToken{access_token: access_token}) do
    {:ok,
     [
       auth_mode: :oauth,
       access_token: access_token,
       with_claude_subscription: true
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
    case get_api_key(scope, provider) do
      %ApiKey{key: key} when is_binary(key) and key != "" ->
        {:ok, {model, Keyword.merge([api_key: key] ++ transport_llm_opts(model), opts)}}

      nil ->
        {:error, :no_api_key}
    end
  end

  defp transport_llm_opts(%LLMDB.Model{provider: :anthropic}),
    do: [anthropic_prompt_cache: true, anthropic_cache_messages: -1]

  defp transport_llm_opts(%LLMDB.Model{}), do: []

  defp resolve_custom_model(scope, provider_id, model_id, opts) do
    with {:ok, provider_id} <- Ecto.UUID.cast(provider_id),
         %CustomProvider{} = provider <- get_owned_custom_provider(scope, provider_id),
         %CustomProviderModel{} <-
           Repo.get_by(CustomProviderModel,
             custom_provider_id: provider_id,
             model_id: model_id
           ) do
      model = %LLMDB.Model{provider: :openai, id: model_id, base_url: provider.base_url}

      llm_opts =
        []
        |> maybe_put_api_key(provider.api_key)
        |> Keyword.merge(opts)
        |> Keyword.merge(custom_provider_transport_opts())

      {:ok, {model, llm_opts}}
    else
      :error -> {:error, :unknown_model}
      nil -> {:error, :unknown_model}
    end
  end

  @placeholder_api_key "sk-no-key-required"

  defp maybe_put_api_key(opts, api_key) when is_binary(api_key) and api_key != "",
    do: Keyword.put(opts, :api_key, api_key)

  defp maybe_put_api_key(opts, _api_key),
    do: Keyword.put(opts, :api_key, @placeholder_api_key)

  defp custom_provider_transport_opts do
    [
      req_http_options: [plugins: [PublicURL], redirect: false],
      on_finch_request: fn request ->
        PublicURL.protect_finch(request, ReqLLM.Application.finch_name())
      end
    ]
  end

  defp resolve_catalog_model(model) do
    with {:ok, {group, model_id}} <- model_parts(model),
         {^group, config} <- Enum.find(providers(), &match?({^group, _}, &1)),
         entry when is_tuple(entry) <-
           Enum.find(config.models, &(elem(&1, 1) == model_id)),
         {_name, ^model_id, model_spec} = model_entry(entry, group),
         {:ok, resolved_model} <- ReqLLM.model(model_spec) do
      credential_source = config |> Map.get(:credential_source, group) |> to_string()
      {:ok, {credential_source, resolved_model}}
    else
      nil -> {:error, :unknown_model}
      :error -> {:error, :unknown_model}
      {:error, _reason} = error -> error
    end
  end

  defp model_entry({name, model_id}, group), do: {name, model_id, model_string(group, model_id)}
  defp model_entry({name, model_id, model_spec}, _group), do: {name, model_id, model_spec}

  def model_from_client_params(nil), do: :error

  def model_from_client_params(%{"provider" => "custom", "value" => value})
      when is_binary(value) and value != "" do
    case String.split(value, ":", parts: 3) do
      ["custom", provider_id, model_id] when provider_id != "" and model_id != "" ->
        {:ok, value}

      _ ->
        :error
    end
  end

  def model_from_client_params(%{"provider" => provider, "value" => value})
      when is_binary(provider) and is_binary(value) and provider != "" and value != "" and
             provider != "custom" do
    {:ok, model_string(provider, value)}
  end

  def model_from_client_params(params) when is_binary(params) do
    case model_parts(params) do
      {:ok, {provider, name}} -> {:ok, model_string(provider, name)}
      :error -> :error
    end
  end

  def model_from_client_params(_params), do: :error

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
    case resolve_oauth_token(scope, provider) do
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
  Returns a human-friendly model name for logs and telemetry.
  """
  def display_model_name(model_ref) when is_binary(model_ref), do: model_ref
  def display_model_name(%{id: id}) when is_binary(id), do: id

  @doc """
  Stores or updates a user API key for a provider.

  On success, broadcasts a config change notification so subscribers
  (e.g. the tasks channel) can push updated config options to the client.
  """
  def upsert_api_key(%Scope{user: %User{} = user}, provider, key) do
    user_id = user.id
    provider = String.downcase(provider)
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
    user.id
    |> ApiKey.provider_names_for_user()
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

        {:ok, token} =
          upsert_oauth_token(
            scope,
            token.provider,
            new_tokens.access_token,
            new_tokens.refresh_token || token.refresh_token,
            expires_at,
            metadata
          )

        token

      {:error, {:token_refresh_failed, 400, %{"error" => "invalid_grant"}}} ->
        delete_oauth_token(scope, token.provider)
        nil

      {:error, _reason} ->
        nil
    end
  end

  defp refresh_oauth_token(%Scope{} = scope, %OAuthToken{provider: "anthropic"} = token) do
    case AnthropicOAuth.refresh_token(token.refresh_token) do
      {:ok, new_tokens} ->
        expires_at = OAuthToken.calculate_expires_at(new_tokens.expires_in)

        {:ok, token} =
          upsert_oauth_token(
            scope,
            token.provider,
            new_tokens.access_token,
            new_tokens.refresh_token || token.refresh_token,
            expires_at
          )

        token

      {:error, {:token_refresh_failed, 400, %{"error" => "invalid_grant"}}} ->
        delete_oauth_token(scope, token.provider)
        nil

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

  @doc """
  Returns model selection data for a user, ready for ACP serialization.

  Resolves which providers the user can access, then builds model groups.
  Returns a domain DTO that ACP translates to `SessionConfigOption` wire format.

  ## Parameters

    * `scope` – the user's `%Scope{}` struct.

  ## Returns

  A map with:
    * `:groups` – list of model group maps, each with `:id`, `:name`, and
      `:options` (list of `%{name: name, value: value}` maps where
      `value` is a serialized `"provider:model"` string)
  """
  def model_config_data(scope) do
    api_key_providers = list_api_key_providers(scope)

    oauth_providers =
      OAuthToken
      |> OAuthToken.for_user(Accounts.scope_user_id(scope))
      |> Repo.all()
      |> Enum.flat_map(fn token ->
        case resolve_oauth_token(scope, token.provider) do
          %OAuthToken{} -> [token.provider]
          nil -> []
        end
      end)

    provider_configs =
      Enum.filter(providers(), fn
        {provider, %{models: [_ | _]} = config} ->
          credential_source = config |> Map.get(:credential_source, provider) |> to_string()
          credential_source in oauth_providers or credential_source in api_key_providers

        {_provider, _config} ->
          false
      end)

    groups =
      Enum.map(provider_configs, fn {provider, config} ->
        options =
          config.models
          |> Enum.map(fn entry ->
            {name, value, _model_spec} = model_entry(entry, provider)

            %{
              name: name,
              value: model_string(provider, value)
            }
          end)

        %{id: provider, name: config.display_name, options: options}
      end)

    groups = groups ++ build_custom_provider_groups(scope)

    %{groups: groups}
  end

  defp build_custom_provider_groups(%Scope{user: %User{id: user_id}}) do
    CustomProvider
    |> CustomProvider.for_user(user_id)
    |> Repo.all()
    |> Repo.preload(:models)
    |> Enum.filter(fn provider -> provider.models != [] end)
    |> Enum.sort_by(& &1.name)
    |> Enum.map(fn provider ->
      options =
        provider.models
        |> Enum.sort_by(& &1.model_id)
        |> Enum.map(fn model ->
          %{name: model.model_id, value: "custom:#{provider.id}:#{model.model_id}"}
        end)

      %{id: "custom:#{provider.id}", name: provider.name, options: options}
    end)
  end

  defp get_owned_custom_provider(%Scope{user: %User{id: user_id}}, id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} ->
        CustomProvider
        |> CustomProvider.for_user(user_id)
        |> Repo.get(id)

      :error ->
        nil
    end
  end

  defp custom_provider_result({:ok, %CustomProvider{} = provider}) do
    provider = Repo.preload(provider, models: CustomProviderModel.ordered())
    {:ok, custom_provider_data(provider)}
  end

  defp custom_provider_result({:error, changeset}), do: {:error, validation_errors(changeset)}

  defp custom_provider_data(%CustomProvider{} = provider) do
    %{
      id: provider.id,
      name: provider.name,
      base_url: provider.base_url,
      has_api_key: not is_nil(provider.api_key),
      models: Enum.map(provider.models, &custom_provider_model_data/1)
    }
  end

  defp custom_provider_model_data(%CustomProviderModel{} = model) do
    %{id: model.id, model_id: model.model_id}
  end

  defp validation_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, options} ->
      Enum.reduce(options, message, fn {key, value}, rendered ->
        String.replace(rendered, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp providers do
    :frontman_server
    |> Application.fetch_env!(:providers)
    |> Enum.map(fn {provider, config} -> {to_string(provider), config} end)
  end

  defp model_parts(model) when is_binary(model) do
    case String.split(model, ":", parts: 2) do
      [provider, name] when provider != "" and name != "" -> {:ok, {provider, name}}
      _invalid -> :error
    end
  end

  defp model_string(provider, name), do: "#{provider}:#{name}"
end
