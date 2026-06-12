defmodule FrontmanServer.Providers.AnthropicOAuthTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.AnthropicOAuth

  describe "generate_pkce/0" do
    test "challenge is derived from verifier" do
      {verifier, challenge} = AnthropicOAuth.generate_pkce()

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
end
