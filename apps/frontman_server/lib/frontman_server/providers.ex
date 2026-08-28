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
    OAuthToken,
    OpenAIOAuth
  }

  @spec list_custom_providers(Scope.t()) :: [map()]
  def list_custom_providers(%Scope{user: %User{id: user_id}}) do
    CustomProvider
    |> CustomProvider.for_user(user_id)
    |> Repo.all()
    |> Enum.map(&custom_provider_data/1)
  end

  @spec create_custom_provider(Scope.t(), map()) :: {:ok, map()} | {:error, map()}
  def create_custom_provider(%Scope{user: %User{id: user_id}}, attrs) do
    %CustomProvider{user_id: user_id}
    |> CustomProvider.changeset(normalize_create_api_key(attrs))
    |> Repo.insert()
    |> custom_provider_result()
  end

  @spec update_custom_provider(Scope.t(), String.t(), map()) ::
          {:ok, map()} | {:error, :not_found | map() | {:stale, map()}}
  def update_custom_provider(%Scope{user: %User{}} = scope, id, attrs) do
    with %CustomProvider{} = provider <- get_owned_custom_provider(scope, id),
         :ok <- require_replacement_attrs(attrs),
         {:ok, lock_version} <- positive_lock_version(attrs),
         {:ok, attrs} <- apply_api_key_change(attrs) do
      provider
      |> Map.replace!(:lock_version, lock_version)
      |> CustomProvider.changeset(attrs)
      |> Ecto.Changeset.optimistic_lock(:lock_version)
      |> Repo.update(stale_error_field: :lock_version)
      |> custom_provider_update_result(scope, id)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec delete_custom_provider(Scope.t(), String.t(), term()) ::
          :ok | {:error, :not_found | map() | {:stale, map()}}
  def delete_custom_provider(%Scope{user: %User{}} = scope, id, lock_version) do
    with {:ok, lock_version} <- delete_lock_version(lock_version),
         %CustomProvider{} = provider <- get_owned_custom_provider(scope, id) do
      provider
      |> Map.replace!(:lock_version, lock_version)
      |> Ecto.Changeset.optimistic_lock(:lock_version)
      |> Repo.delete(stale_error_field: :lock_version)
      |> custom_provider_delete_result(scope, id)
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Resolves model access into ReqLLM arguments for a request.

  This is the primary entry point for provider auth resolution at the domain layer.
  Call this before making LLM calls, not inside LLM implementations.

  ## Parameters
    - scope: The user scope.
    - model: The model string (e.g., "openrouter:openai/gpt-4")

  ## Returns
    - `{:ok, {model_spec, llm_opts}}` - Ready to use for LLM calls
    - `{:error, :no_api_key}` - No API key available
  """
  @spec resolve_model_access(Scope.t(), String.t() | nil, keyword()) ::
          {:ok, {LLMDB.Model.t(), keyword()}} | {:error, term()}
  def resolve_model_access(scope, model, opts \\ [])

  def resolve_model_access(%Scope{}, nil, _opts), do: {:error, :missing_model}

  def resolve_model_access(%Scope{} = scope, "custom:" <> rest, opts)
      when is_binary(rest) and rest != "" do
    case String.split(rest, ":", parts: 2) do
      [provider_id, model_id] when provider_id != "" and model_id != "" ->
        resolve_custom_model(scope, provider_id, model_id, opts)

      _ ->
        {:error, :unknown_model}
    end
  end

  def resolve_model_access(%Scope{} = scope, model, opts)
      when is_binary(model) and model != "" do
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

  def resolve_model_access(%Scope{}, _model, _opts), do: {:error, :missing_model}

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
         true <- model_id in provider.models do
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
      false -> {:error, :unknown_model}
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

  @spec parse_model_ref(term()) :: {:ok, String.t()} | :error
  def parse_model_ref("custom:" <> rest = model_ref) do
    case String.split(rest, ":", parts: 2) do
      [provider_id, model_id] when provider_id != "" and model_id != "" -> {:ok, model_ref}
      _ -> :error
    end
  end

  def parse_model_ref(params) when is_binary(params) do
    case model_parts(params) do
      {:ok, {provider, name}} -> {:ok, model_string(provider, name)}
      :error -> :error
    end
  end

  def parse_model_ref(_params), do: :error

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

  @spec resolve_oauth_connection_status(Scope.t(), String.t()) :: map()
  def resolve_oauth_connection_status(%Scope{} = scope, provider) do
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
  Stores or updates a user API key for a provider.

  On success, broadcasts a config change notification so subscribers
  (e.g. the tasks channel) can push updated config options to the client.
  """
  @spec upsert_api_key(Scope.t(), String.t(), String.t()) :: :ok | {:error, map()}
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
      {:ok, _record} ->
        broadcast_config_changed(user_id)
        :ok

      {:error, changeset} ->
        {:error, validation_errors(changeset)}
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

  defp upsert_oauth_token(
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

  defp get_oauth_token(%Scope{user: %User{} = user}, provider) do
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

  defp broadcast_config_changed(user_id) when is_binary(user_id) do
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
  @spec available_models(Scope.t()) :: %{groups: [map()]}
  def available_models(%Scope{} = scope) do
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
    |> Enum.filter(fn provider -> provider.models != [] end)
    |> Enum.sort_by(& &1.name)
    |> Enum.map(fn provider ->
      options =
        Enum.map(provider.models, fn model_id ->
          %{name: model_id, value: "custom:#{provider.id}:#{model_id}"}
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
    broadcast_config_changed(provider.user_id)
    {:ok, custom_provider_data(provider)}
  end

  defp custom_provider_result({:error, changeset}), do: {:error, validation_errors(changeset)}

  defp custom_provider_update_result({:error, changeset}, scope, id),
    do: custom_provider_error(changeset, scope, id)

  defp custom_provider_update_result(result, _scope, _id), do: custom_provider_result(result)

  defp custom_provider_delete_result({:ok, provider}, _scope, _id) do
    broadcast_config_changed(provider.user_id)
    :ok
  end

  defp custom_provider_delete_result({:error, changeset}, scope, id),
    do: custom_provider_error(changeset, scope, id)

  defp custom_provider_error(changeset, scope, id) do
    if stale_changeset?(changeset),
      do: stale_result(scope, id),
      else: {:error, validation_errors(changeset)}
  end

  defp custom_provider_data(%CustomProvider{} = provider) do
    %{
      id: provider.id,
      name: provider.name,
      base_url: provider.base_url,
      has_api_key: not is_nil(provider.api_key),
      models: provider.models,
      lock_version: provider.lock_version
    }
  end

  defp normalize_create_api_key(%{"api_key" => ""} = attrs),
    do: Map.put(attrs, "api_key", nil)

  defp normalize_create_api_key(attrs), do: attrs

  defp require_replacement_attrs(attrs) do
    case Enum.reject(
           ~w(name base_url models lock_version api_key_change),
           &Map.has_key?(attrs, &1)
         ) do
      [] -> :ok
      keys -> {:error, Map.new(keys, &{String.to_existing_atom(&1), ["is required"]})}
    end
  end

  defp apply_api_key_change(%{"api_key_change" => %{"action" => "keep"}} = attrs),
    do: {:ok, Map.drop(attrs, ["api_key_change", "api_key"])}

  defp apply_api_key_change(%{"api_key_change" => %{"action" => "clear"}} = attrs),
    do: {:ok, attrs |> Map.delete("api_key_change") |> Map.put("api_key", nil)}

  defp apply_api_key_change(
         %{"api_key_change" => %{"action" => "replace", "value" => value}} = attrs
       )
       when is_binary(value) and value != "",
       do: {:ok, attrs |> Map.delete("api_key_change") |> Map.put("api_key", value)}

  defp apply_api_key_change(%{"api_key_change" => %{"action" => "replace"}}),
    do: {:error, %{api_key_change: ["replacement value must not be empty"]}}

  defp apply_api_key_change(_attrs),
    do: {:error, %{api_key_change: ["has an invalid action"]}}

  defp positive_lock_version(%{"lock_version" => version}), do: positive_lock_version(version)

  defp positive_lock_version(attrs) when is_map(attrs),
    do: {:error, %{lock_version: ["is required"]}}

  defp positive_lock_version(version) when is_integer(version) and version > 0, do: {:ok, version}

  defp positive_lock_version(_version),
    do: {:error, %{lock_version: ["must be a positive integer"]}}

  defp delete_lock_version(version) when is_binary(version) do
    case Integer.parse(version) do
      {parsed, ""} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, %{lock_version: ["must be a positive integer"]}}
    end
  end

  defp delete_lock_version(version), do: positive_lock_version(version)

  defp stale_changeset?(changeset) do
    Enum.any?(changeset.errors, fn {_field, {_message, options}} -> options[:stale] end)
  end

  defp stale_result(scope, id) do
    case get_owned_custom_provider(scope, id) do
      %CustomProvider{} = provider -> {:error, {:stale, custom_provider_data(provider)}}
      nil -> {:error, :not_found}
    end
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
