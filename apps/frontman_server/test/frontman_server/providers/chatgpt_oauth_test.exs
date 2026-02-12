defmodule FrontmanServer.Providers.ChatGPTOAuthTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.ChatGPTOAuth

  defp build_jwt(claims) do
    header = Base.url_encode64(Jason.encode!(%{"alg" => "RS256"}), padding: false)
    payload = Base.url_encode64(Jason.encode!(claims), padding: false)
    signature = Base.url_encode64("fake_signature", padding: false)
    "#{header}.#{payload}.#{signature}"
  end

  describe "extract_account_id/1" do
    test "extracts account_id from OpenAI auth claim" do
      jwt =
        build_jwt(%{"https://api.openai.com/auth" => %{"chatgpt_account_id" => "acct_123"}})

      assert {:ok, "acct_123"} = ChatGPTOAuth.extract_account_id(jwt)
    end

    test "extracts account_id from top-level claim" do
      jwt = build_jwt(%{"chatgpt_account_id" => "acct_456"})
      assert {:ok, "acct_456"} = ChatGPTOAuth.extract_account_id(jwt)
    end

    test "extracts account_id from organizations array" do
      jwt = build_jwt(%{"organizations" => [%{"id" => "org_789"}]})
      assert {:ok, "org_789"} = ChatGPTOAuth.extract_account_id(jwt)
    end

    test "returns error for JWT with no account_id" do
      jwt = build_jwt(%{"sub" => "user_1"})
      assert {:error, :not_found} = ChatGPTOAuth.extract_account_id(jwt)
    end

    test "returns error for invalid JWT" do
      assert {:error, :not_found} = ChatGPTOAuth.extract_account_id("not-a-valid-jwt")
    end
  end

  describe "extract_account_id_from_tokens/1" do
    test "prefers id_token over access_token" do
      id_jwt = build_jwt(%{"chatgpt_account_id" => "from_id_token"})
      access_jwt = build_jwt(%{"chatgpt_account_id" => "from_access_token"})

      result =
        ChatGPTOAuth.extract_account_id_from_tokens(%{
          id_token: id_jwt,
          access_token: access_jwt,
          refresh_token: "rt_xxx",
          expires_in: 3600
        })

      assert result == "from_id_token"
    end

    test "falls back to access_token when id_token has no account_id" do
      id_jwt = build_jwt(%{"sub" => "user_1"})
      access_jwt = build_jwt(%{"chatgpt_account_id" => "from_access_token"})

      result =
        ChatGPTOAuth.extract_account_id_from_tokens(%{
          id_token: id_jwt,
          access_token: access_jwt,
          refresh_token: "rt_xxx",
          expires_in: 3600
        })

      assert result == "from_access_token"
    end

    test "returns nil when neither token contains account_id" do
      id_jwt = build_jwt(%{"sub" => "user_1"})
      access_jwt = build_jwt(%{"sub" => "user_1"})

      result =
        ChatGPTOAuth.extract_account_id_from_tokens(%{
          id_token: id_jwt,
          access_token: access_jwt,
          refresh_token: "rt_xxx",
          expires_in: 3600
        })

      assert is_nil(result)
    end

    test "accepts the full token map shape from exchange_device_code" do
      # This test captures the invariant: extract_account_id_from_tokens
      # must accept the exact map shape returned by exchange_device_code/2,
      # which always includes all four keys.
      jwt = build_jwt(%{"chatgpt_account_id" => "acct_test"})

      token_map = %{
        access_token: "at_xxx",
        refresh_token: "rt_xxx",
        id_token: jwt,
        expires_in: 3600
      }

      assert "acct_test" = ChatGPTOAuth.extract_account_id_from_tokens(token_map)
    end
  end
end
