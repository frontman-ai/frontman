defmodule FrontmanServer.Providers.OAuthHelpers do
  @moduledoc """
  Shared helpers for OAuth provider integrations.

  Contains common PKCE generation and token expiry calculation
  used by both Anthropic and ChatGPT OAuth flows.
  """

  @doc """
  Generates a PKCE verifier and challenge.

  Returns `{verifier, challenge}` where:
  - verifier: Random 32-byte string, base64url encoded (no padding)
  - challenge: SHA-256 hash of verifier, base64url encoded (no padding)
  """
  @spec generate_pkce() :: {String.t(), String.t()}
  def generate_pkce do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  @doc """
  Calculates the expiration DateTime from expires_in seconds.
  """
  @spec calculate_expires_at(integer()) :: DateTime.t()
  def calculate_expires_at(expires_in) when is_integer(expires_in) do
    DateTime.utc_now()
    |> DateTime.add(expires_in, :second)
    |> DateTime.truncate(:second)
  end

  @doc """
  Generates a random state parameter for OAuth flows.
  Returns a 32-byte random string, base64url encoded (no padding).
  """
  @spec generate_state() :: String.t()
  def generate_state do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
