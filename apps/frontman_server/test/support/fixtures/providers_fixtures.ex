defmodule FrontmanServer.ProvidersFixtures do
  @moduledoc """
  Test fixtures and helpers for the Providers context.
  """

  use Boundary,
    top_level?: true,
    check: [in: false, out: false]

  # ── PNG fixtures ────────────────────────────────────────────────────

  @doc """
  Builds a minimal PNG binary with the given dimensions.
  Only enough structure for `Image.check_dimensions/2` to parse.
  """
  def png_fixture(width, height) do
    <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
      <<0::32>> <> "IHDR" <> <<width::32, height::32>> <> <<0::8>>
  end

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
