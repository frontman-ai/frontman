# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Providers.ResolvedKey do
  @moduledoc """
  A resolved connection to an LLM provider.

  Created by `Providers.prepare_api_key/3` at the domain layer, this struct
  encapsulates everything needed to talk to a specific model: credentials,
  provider-specific wiring (Codex endpoint, OAuth mode), and transformation
  hints (MCP prefix, identity override).

  Use `to_llm_args/2` to derive the `{model_spec, llm_opts}` pair that
  `ReqLLM.stream_text/3` expects. This absorbs all provider-specific wiring
  (Codex endpoint, OAuth headers, model normalization) so callers don't need
  to know about those details.

  ## Fields

  - `:provider` - Provider name (e.g., "openrouter", "anthropic")
  - `:api_key` - The resolved API key value
  - `:key_source` - Where the key came from (`:user_key`, `:env_key`, `:server_key`, `:oauth_token`)
  - `:model` - The full model string (e.g., "openrouter:openai/gpt-4")
  - `:requires_mcp_prefix` - Whether tool names need `mcp_` prefix (for Claude Code OAuth)
  - `:identity_override` - Optional identity string to prepend to system messages (for Claude Code OAuth)
  - `:auth_mode` - Authentication mode: `:api_key` (default) or `:oauth` (Bearer token)
  """

  use TypedStruct

  alias FrontmanServer.Providers.Codex

  @type key_source :: :user_key | :env_key | :server_key | :oauth_token

  typedstruct do
    field(:provider, String.t(), enforce: true)
    field(:api_key, String.t(), enforce: true)
    field(:key_source, key_source(), enforce: true)
    field(:model, String.t(), enforce: true)
    # LLM transformation hints (for Claude Code OAuth)
    field(:requires_mcp_prefix, boolean(), default: false)
    field(:identity_override, String.t() | nil, default: nil)
    # Authentication mode — :api_key (default) or :oauth (Bearer token)
    field(:auth_mode, atom(), default: :api_key)
    # ChatGPT-specific fields (for Codex API)
    field(:chatgpt_account_id, String.t() | nil, default: nil)
    field(:codex_endpoint, String.t() | nil, default: nil)
  end

  @doc """
  Creates a new ResolvedKey struct.

  ## Options

  - `:requires_mcp_prefix` - Whether tool names need `mcp_` prefix (default: false)
  - `:identity_override` - Identity string to prepend to system messages (default: nil)
  - `:auth_mode` - Authentication mode: `:api_key` (default) or `:oauth`
  - `:chatgpt_account_id` - ChatGPT account ID for Codex API (default: nil)
  - `:codex_endpoint` - Codex API endpoint URL (default: nil)
  """
  def new(provider, api_key, key_source, model, opts \\ []) do
    %__MODULE__{
      provider: provider,
      api_key: api_key,
      key_source: key_source,
      model: model,
      requires_mcp_prefix: Keyword.get(opts, :requires_mcp_prefix, false),
      identity_override: Keyword.get(opts, :identity_override),
      auth_mode: Keyword.get(opts, :auth_mode, :api_key),
      chatgpt_account_id: Keyword.get(opts, :chatgpt_account_id),
      codex_endpoint: Keyword.get(opts, :codex_endpoint)
    }
  end

  @doc """
  Derives the `{model_spec, llm_opts}` pair for `ReqLLM.stream_text/3`.

  Builds ReqLLM-compatible options from the resolved key and handles all
  provider-specific wiring internally:

    * For Codex (ChatGPT OAuth): normalizes the model alias, patches the
      base URL and routes through the `openai_codex` provider
    * For all providers: sets `api_key` (or `auth_mode` + `access_token` for OAuth), `requires_mcp_prefix`,
      and `identity_override`

  Caller-provided `extra_opts` (e.g., `max_tokens: 30`) are merged in and
  can be overridden by provider-specific requirements (Codex strips `max_tokens`).

  ## Examples

      {model_spec, llm_opts} = ResolvedKey.to_llm_args(resolved_key, max_tokens: 16_384)
      ReqLLM.stream_text(model_spec, messages, llm_opts)
  """
  @spec to_llm_args(t(), keyword()) :: {String.t() | map(), keyword()}
  def to_llm_args(%__MODULE__{} = key, extra_opts \\ []) do
    base_opts =
      case key.auth_mode do
        :oauth ->
          [
            auth_mode: :oauth,
            access_token: key.api_key,
            requires_mcp_prefix: key.requires_mcp_prefix,
            identity_override: key.identity_override
          ]

        :api_key ->
          [
            api_key: key.api_key,
            requires_mcp_prefix: key.requires_mcp_prefix,
            identity_override: key.identity_override
          ]
      end
      |> Keyword.merge(extra_opts)

    case key.codex_endpoint do
      endpoint when is_binary(endpoint) ->
        model_string = Codex.normalize_model(key.model)
        llm_opts = Codex.patch_llm_opts(base_opts, endpoint, key.chatgpt_account_id)
        model_spec = Codex.resolve_model(model_string)
        {model_spec, llm_opts}

      _ ->
        {key.model, base_opts}
    end
  end
end
