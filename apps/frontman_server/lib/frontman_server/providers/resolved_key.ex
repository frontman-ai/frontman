defmodule FrontmanServer.Providers.ResolvedKey do
  @moduledoc """
  Represents a resolved API key ready for use in LLM calls.

  This struct is created by `Providers.prepare_api_key/3` at the domain layer
  and passed through to agents and tools. It encapsulates all the information
  needed to make LLM calls and track usage.

  ## Fields

  - `:provider` - Provider name (e.g., "openrouter", "anthropic")
  - `:api_key` - The resolved API key value
  - `:key_source` - Where the key came from (`:user_key`, `:env_key`, `:server_key`, `:oauth_token`)
  - `:model` - The full model string (e.g., "openrouter:openai/gpt-4")
  - `:requires_mcp_prefix` - Whether tool names need `mcp_` prefix (for Claude Code OAuth)
  - `:identity_override` - Optional identity string to prepend to system messages (for Claude Code OAuth)
  - `:oauth_mode` - Whether to use OAuth authentication (Bearer token) instead of API key
  """

  use TypedStruct

  @type key_source :: :user_key | :env_key | :server_key | :oauth_token

  typedstruct do
    field(:provider, String.t(), enforce: true)
    field(:api_key, String.t(), enforce: true)
    field(:key_source, key_source(), enforce: true)
    field(:model, String.t(), enforce: true)
    # LLM transformation hints (for Claude Code OAuth)
    field(:requires_mcp_prefix, boolean(), default: false)
    field(:identity_override, String.t() | nil, default: nil)
    # Authentication mode (for OAuth tokens)
    field(:oauth_mode, boolean(), default: false)
    # ChatGPT-specific fields (for Codex API)
    field(:chatgpt_account_id, String.t() | nil, default: nil)
    field(:codex_endpoint, String.t() | nil, default: nil)
  end

  @doc """
  Creates a new ResolvedKey struct.

  ## Options

  - `:requires_mcp_prefix` - Whether tool names need `mcp_` prefix (default: false)
  - `:identity_override` - Identity string to prepend to system messages (default: nil)
  - `:oauth_mode` - Whether to use OAuth authentication (default: false)
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
      oauth_mode: Keyword.get(opts, :oauth_mode, false),
      chatgpt_account_id: Keyword.get(opts, :chatgpt_account_id),
      codex_endpoint: Keyword.get(opts, :codex_endpoint)
    }
  end
end
