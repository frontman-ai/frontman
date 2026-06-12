defmodule FrontmanServer.Providers.OpenAIOAuthTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.OpenAIOAuth

  defp build_jwt(claims) do
    header = Base.url_encode64(Jason.encode!(%{"alg" => "RS256"}), padding: false)
    payload = Base.url_encode64(Jason.encode!(claims), padding: false)
    signature = Base.url_encode64("fake_signature", padding: false)
    "#{header}.#{payload}.#{signature}"
  end

  describe "extract_account_id_from_tokens/1" do
    test "extracts account_id from OpenAI auth claim" do
      jwt =
        build_jwt(%{"https://api.openai.com/auth" => %{"chatgpt_account_id" => "acct_123"}})

      assert "acct_123" = OpenAIOAuth.extract_account_id_from_tokens(%{id_token: jwt})
    end

    test "extracts account_id from top-level claim" do
      jwt = build_jwt(%{"chatgpt_account_id" => "acct_456"})

      assert "acct_456" = OpenAIOAuth.extract_account_id_from_tokens(%{id_token: jwt})
    end

    test "extracts account_id from organizations array" do
      jwt = build_jwt(%{"organizations" => [%{"id" => "org_789"}]})

      assert "org_789" = OpenAIOAuth.extract_account_id_from_tokens(%{id_token: jwt})
    end
  end
end
