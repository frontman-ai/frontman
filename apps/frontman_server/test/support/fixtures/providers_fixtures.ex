defmodule FrontmanServer.ProvidersFixtures do
  @moduledoc """
  Test fixtures and helpers for the Providers context.
  """

  use Boundary,
    top_level?: true,
    check: [in: false, out: false]

  alias FrontmanServer.Providers.{Registry, ResolvedKey}

  # ── Server key helpers ──────────────────────────────────────────────

  @doc """
  Temporarily sets a server API key for the given provider.
  Restores the original value on test exit.
  """
  def with_server_key(provider, value) do
    config_key = Registry.config_key(provider)
    original = Application.get_env(:frontman_server, config_key)
    Application.put_env(:frontman_server, config_key, value)

    ExUnit.Callbacks.on_exit(fn ->
      if original,
        do: Application.put_env(:frontman_server, config_key, original),
        else: Application.delete_env(:frontman_server, config_key)
    end)

    value
  end

  @doc """
  Clears a server API key for the given provider. Restores on test exit.
  """
  def without_server_key(provider) do
    config_key = Registry.config_key(provider)
    original = Application.get_env(:frontman_server, config_key)
    Application.delete_env(:frontman_server, config_key)

    ExUnit.Callbacks.on_exit(fn ->
      if original,
        do: Application.put_env(:frontman_server, config_key, original)
    end)
  end

  # ── PNG fixtures ────────────────────────────────────────────────────

  @doc """
  Builds a minimal PNG binary with the given dimensions.
  Only enough structure for `Image.check_dimensions/2` to parse.
  """
  def png_fixture(width, height) do
    <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
      <<0::32>> <> "IHDR" <> <<width::32, height::32>> <> <<0::8>>
  end

  # ── ResolvedKey builders ────────────────────────────────────────────

  @doc """
  Builds a `ResolvedKey` with sensible per-provider defaults.
  Override any field via opts.
  """
  def resolved_key_fixture(provider \\ "anthropic", opts \\ []) do
    merged = Keyword.merge(defaults_for(provider), opts)

    rk_opts =
      Keyword.take(merged, [
        :auth_mode,
        :requires_mcp_prefix,
        :identity_override,
        :chatgpt_account_id,
        :codex_endpoint
      ])

    ResolvedKey.new(
      provider,
      merged[:api_key],
      merged[:key_source],
      merged[:model],
      rk_opts
    )
  end

  defp defaults_for("anthropic") do
    [api_key: "sk-ant-test", key_source: :env_key, model: "anthropic:claude-sonnet-4-5"]
  end

  defp defaults_for("openrouter") do
    [api_key: "sk-or-test", key_source: :user_key, model: "openrouter:openai/gpt-5.5"]
  end

  defp defaults_for("fireworks") do
    [
      api_key: "sk-fireworks-test-key",
      key_source: :env_key,
      model: "fireworks:accounts/fireworks/routers/kimi-k2p5-turbo"
    ]
  end

  defp defaults_for("openai") do
    [
      api_key: "chatgpt-token",
      key_source: :oauth_token,
      model: "openai:gpt-5.3-codex",
      auth_mode: :oauth,
      codex_endpoint: "https://chatgpt.com/backend-api/codex/responses"
    ]
  end

  defp defaults_for(_), do: [api_key: "test-key", key_source: :env_key, model: "provider:model"]

  # ── Channel prompt builder ──────────────────────────────────────────

  @doc """
  Builds a JSON-RPC `session/prompt` message for channel tests.

  Options: `:id`, `:text`, `:_meta`.
  """
  def prompt_request(opts \\ []) do
    id = Keyword.get(opts, :id, 1)
    text = Keyword.get(opts, :text, "Hello")
    meta = Keyword.get(opts, :_meta, %{})

    params = %{
      "prompt" => [
        %{"type" => "text", "text" => text}
      ]
    }

    params = if meta == %{}, do: params, else: Map.put(params, "_meta", meta)

    %{"jsonrpc" => "2.0", "id" => id, "method" => "session/prompt", "params" => params}
  end

  # ── OAuth token helper ──────────────────────────────────────────────

  @doc """
  Inserts an OAuth token expiring in 1 hour for the given scope + provider.
  """
  def setup_oauth_token(scope, provider) do
    expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

    {:ok, token} =
      FrontmanServer.Providers.upsert_oauth_token(
        scope,
        provider,
        "access-token",
        "refresh-token",
        expires_at
      )

    token
  end
end
