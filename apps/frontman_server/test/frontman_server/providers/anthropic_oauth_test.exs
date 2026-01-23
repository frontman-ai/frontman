defmodule FrontmanServer.Providers.AnthropicOAuthTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.AnthropicOAuth

  describe "generate_pkce/0" do
    test "generates verifier and challenge" do
      {verifier, challenge} = AnthropicOAuth.generate_pkce()

      assert is_binary(verifier)
      assert is_binary(challenge)
      # Base64url encoded 32 bytes = ~43 chars
      assert String.length(verifier) >= 40
      assert String.length(challenge) >= 40
    end

    test "generates unique values each time" do
      {verifier1, _} = AnthropicOAuth.generate_pkce()
      {verifier2, _} = AnthropicOAuth.generate_pkce()

      refute verifier1 == verifier2
    end

    test "challenge is derived from verifier" do
      {verifier, challenge} = AnthropicOAuth.generate_pkce()

      # Verify the challenge is SHA-256 of verifier
      expected_challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
      assert challenge == expected_challenge
    end
  end

  describe "build_authorize_url/2" do
    test "builds valid URL with required params" do
      {verifier, challenge} = AnthropicOAuth.generate_pkce()
      url = AnthropicOAuth.build_authorize_url(challenge, verifier)

      assert url =~ "https://claude.ai/oauth/authorize"
      assert url =~ "client_id="
      assert url =~ "response_type=code"
      assert url =~ "redirect_uri="
      assert url =~ "scope="
      assert url =~ "code_challenge=#{URI.encode_www_form(challenge)}"
      assert url =~ "code_challenge_method=S256"
      assert url =~ "state=#{URI.encode_www_form(verifier)}"
    end
  end

  describe "calculate_expires_at/1" do
    test "calculates future expiration time" do
      now = DateTime.utc_now()
      expires_at = AnthropicOAuth.calculate_expires_at(3600)

      # Should be approximately 1 hour in the future
      diff = DateTime.diff(expires_at, now)
      assert diff >= 3599 and diff <= 3601
    end

    test "truncates to seconds" do
      expires_at = AnthropicOAuth.calculate_expires_at(100)

      # Microsecond should be 0
      assert expires_at.microsecond == {0, 0}
    end
  end
end
