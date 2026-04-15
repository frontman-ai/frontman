# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.Registry do
  @moduledoc """
  Centralised provider registry.

  Provider definitions live in `config/config.exs` under the
  `:frontman_server, :providers` key.  This module reads them at
  compile time via `Application.compile_env!/2` so adding a new
  provider is a single config entry — no code changes needed.

  See `config/config.exs` for the full field documentation.
  """

  @type provider_entry :: %{
          config_key: atom(),
          env_var: String.t(),
          env_key_name: String.t() | nil,
          display_name: String.t(),
          priority: non_neg_integer(),
          oauth_provider: String.t() | nil,
          env_key_param: String.t() | nil,
          max_image_dimension: pos_integer() | nil
        }

  @providers Application.compile_env!(:frontman_server, :providers)

  @doc """
  Returns the full provider map.  Mostly useful for enumeration / debugging.
  """
  @spec all() :: %{String.t() => provider_entry()}
  def all, do: @providers

  @doc """
  Returns `true` if the provider string is known to the registry.
  """
  @spec known?(String.t()) :: boolean()
  def known?(provider) when is_binary(provider) do
    Map.has_key?(@providers, String.downcase(provider))
  end

  # ── Field accessors ─────────────────────────────────────────────────

  @doc """
  Returns the `Application.get_env` config key atom for the given provider,
  or `nil` if the provider is unknown.

  ## Examples

      iex> Registry.config_key("openrouter")
      :openrouter_api_key

      iex> Registry.config_key("unknown")
      nil
  """
  @spec config_key(String.t()) :: atom() | nil
  def config_key(provider) when is_binary(provider) do
    get_field(provider, :config_key)
  end

  @doc """
  Returns the human-readable display name for a provider, or `nil`.
  """
  @spec display_name(String.t()) :: String.t() | nil
  def display_name(provider) when is_binary(provider) do
    get_field(provider, :display_name)
  end

  @doc """
  Returns the OAuth provider string used for token lookup, or `nil` when
  OAuth is not available for this provider.

  Most providers use their own id, but `"openai"` stores tokens as `"chatgpt"`.
  """
  @spec oauth_provider(String.t()) :: String.t() | nil
  def oauth_provider(provider) when is_binary(provider) do
    get_field(provider, :oauth_provider)
  end

  @doc """
  Returns the query parameter name the client sends to indicate it has an
  env key for this provider, or `nil` when not applicable.
  """
  @spec env_key_param(String.t()) :: String.t() | nil
  def env_key_param(provider) when is_binary(provider) do
    get_field(provider, :env_key_param)
  end

  @doc """
  Returns the display priority for a provider (lower = shown first), or `nil`.
  """
  @spec priority(String.t()) :: non_neg_integer() | nil
  def priority(provider) when is_binary(provider) do
    get_field(provider, :priority)
  end

  @doc """
  Returns the maximum allowed image dimension (pixels per side) for a provider,
  or `nil` if the provider does not enforce a hard limit.

  Providers that return `nil` are assumed to auto-resize images.
  """
  @spec max_image_dimension(String.t()) :: pos_integer() | nil
  def max_image_dimension(provider) when is_binary(provider) do
    get_field(provider, :max_image_dimension)
  end

  # ── Env key helpers ────────────────────────────────────────────────

  @doc """
  Returns a map of `%{env_key_name => provider}` for providers that accept
  client-forwarded keys.

  Used internally by `extract_env_keys/1` but also useful for testing.

  ## Examples

      iex> Registry.env_key_mapping()
      %{"openrouterKeyValue" => "openrouter", "anthropicKeyValue" => "anthropic"}
  """
  @spec env_key_mapping() :: %{String.t() => String.t()}
  def env_key_mapping do
    for {provider, %{env_key_name: name}} when is_binary(name) <- @providers,
        into: %{} do
      {name, provider}
    end
  end

  @doc """
  Extracts provider API keys from a metadata map sent by the client.

  This replaces the duplicated `extract_env_api_key*` functions in both
  `TaskChannel` and `TasksChannel`.

  ## Parameters

    * `metadata` – the metadata map from client params.  Keys like
      `"openrouterKeyValue"` are mapped to their provider name.

  ## Returns

  A map of `%{provider => api_key}` for every key present and non-empty.

  ## Examples

      iex> Registry.extract_env_keys(%{"openrouterKeyValue" => "sk-or-123"})
      %{"openrouter" => "sk-or-123"}

      iex> Registry.extract_env_keys(%{})
      %{}
  """
  @spec extract_env_keys(map()) :: %{String.t() => String.t()}
  def extract_env_keys(metadata) when is_map(metadata) do
    nested_keys =
      case metadata["envApiKey"] do
        env_api_key when is_map(env_api_key) -> extract_env_keys(env_api_key)
        _ -> %{}
      end

    top_level_keys =
      for {meta_key, provider} <- env_key_mapping(),
          key = metadata[meta_key],
          is_binary(key) and key != "",
          into: %{} do
        {provider, key}
      end

    Map.merge(top_level_keys, nested_keys)
  end

  def extract_env_keys(_), do: %{}

  # ── Server key lookup ──────────────────────────────────────────────

  @doc """
  Fetches the server API key for a provider from application config.

  ## Examples

      iex> Registry.get_server_api_key("openrouter")
      # value from Application.get_env(:frontman_server, :openrouter_api_key)
  """
  @spec get_server_api_key(String.t()) :: String.t() | nil
  def get_server_api_key(provider) when is_binary(provider) do
    case config_key(provider) do
      nil -> nil
      key -> Application.get_env(:frontman_server, key)
    end
  end

  # ── Private ────────────────────────────────────────────────────────

  defp get_field(provider, field) do
    case Map.get(@providers, String.downcase(provider)) do
      %{} = entry -> Map.get(entry, field)
      nil -> nil
    end
  end
end
