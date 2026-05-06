defmodule FrontmanServer.Providers.ResolvedKeyTest do
  @moduledoc """
  Tests for `ResolvedKey.to_llm_args/2` — translates resolved keys into
  `{model_spec, llm_opts}` pairs for each provider type.
  """
  use ExUnit.Case, async: true

  import FrontmanServer.ProvidersFixtures

  alias FrontmanServer.Providers.ResolvedKey

  describe "to_llm_args/2 for standard Anthropic key" do
    test "returns model string and base opts" do
      key = resolved_key_fixture("anthropic", api_key: "sk-ant-123")

      {model_spec, llm_opts} = ResolvedKey.to_llm_args(key, max_tokens: 16_384)

      assert model_spec == "anthropic:claude-sonnet-4-5"
      assert llm_opts[:api_key] == "sk-ant-123"
      assert llm_opts[:max_tokens] == 16_384
      refute Keyword.has_key?(llm_opts, :auth_mode)
      assert llm_opts[:requires_mcp_prefix] == false
      refute Keyword.has_key?(llm_opts, :with_claude_subscription)
      refute Keyword.has_key?(llm_opts, :base_url)
    end
  end

  describe "to_llm_args/2 for Anthropic OAuth" do
    test "returns model string with OAuth transformation opts" do
      key =
        resolved_key_fixture("anthropic",
          api_key: "oauth-access-token",
          key_source: :oauth_token,
          requires_mcp_prefix: true,
          with_claude_subscription: true,
          auth_mode: :oauth
        )

      {model_spec, llm_opts} = ResolvedKey.to_llm_args(key, max_tokens: 16_384)

      assert model_spec == "anthropic:claude-sonnet-4-5"
      assert llm_opts[:access_token] == "oauth-access-token"
      assert llm_opts[:auth_mode] == :oauth
      assert llm_opts[:requires_mcp_prefix] == true
      assert llm_opts[:with_claude_subscription] == true
      assert llm_opts[:max_tokens] == 16_384
      refute Keyword.has_key?(llm_opts, :api_key)
    end
  end

  describe "to_llm_args/2 for OpenRouter key" do
    test "returns model string and base opts" do
      key = resolved_key_fixture("openrouter", api_key: "sk-or-456")

      {model_spec, llm_opts} = ResolvedKey.to_llm_args(key, max_tokens: 16_384)

      assert model_spec == "openrouter:openai/gpt-5.5"
      assert llm_opts[:api_key] == "sk-or-456"
      assert llm_opts[:max_tokens] == 16_384
      refute Keyword.has_key?(llm_opts, :auth_mode)
    end
  end

  describe "to_llm_args/2 for Codex (ChatGPT OAuth)" do
    test "routes through openai_codex, patches base_url, and strips max_tokens" do
      key =
        resolved_key_fixture("openai",
          api_key: "chatgpt-access-token",
          chatgpt_account_id: "acc-789"
        )

      {model_spec, llm_opts} = ResolvedKey.to_llm_args(key, max_tokens: 16_384)

      case model_spec do
        %{provider: provider, id: id} ->
          assert provider == :openai_codex
          assert id == "gpt-5.3-codex"

        string when is_binary(string) ->
          assert string == "openai_codex:gpt-5.3-codex"
      end

      assert llm_opts[:base_url] == "https://chatgpt.com/backend-api/codex"
      assert llm_opts[:chatgpt_account_id] == "acc-789"
      assert llm_opts[:access_token] == "chatgpt-access-token"
      assert llm_opts[:auth_mode] == :oauth
      refute Keyword.has_key?(llm_opts, :api_key)
      refute Keyword.has_key?(llm_opts, :max_tokens)
      refute Keyword.has_key?(llm_opts, :provider_options)
      refute Keyword.has_key?(llm_opts, :req_http_options)
    end

    test "normalizes codex-5.3 alias before resolution" do
      key = resolved_key_fixture("openai", model: "openai:codex-5.3")

      {model_spec, _llm_opts} = ResolvedKey.to_llm_args(key)

      case model_spec do
        %{provider: provider, id: id} ->
          assert provider == :openai_codex
          assert id == "gpt-5.3-codex"

        string when is_binary(string) ->
          assert string == "openai_codex:gpt-5.3-codex"
      end
    end

    test "handles nil chatgpt_account_id" do
      key = resolved_key_fixture("openai")

      {_model_spec, llm_opts} = ResolvedKey.to_llm_args(key)

      refute Keyword.has_key?(llm_opts, :chatgpt_account_id)
    end
  end

  describe "to_llm_args/2 extra_opts merging" do
    test "caller opts are merged into base opts" do
      key = resolved_key_fixture("anthropic")

      {_model_spec, llm_opts} =
        ResolvedKey.to_llm_args(key, max_tokens: 8_192, temperature: 0.7)

      assert llm_opts[:max_tokens] == 8_192
      assert llm_opts[:temperature] == 0.7
    end
  end
end
