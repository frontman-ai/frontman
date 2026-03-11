defmodule FrontmanServer.Providers.ResolvedKeyTest do
  @moduledoc """
  Tests for `ResolvedKey.to_llm_args/2` — the single function that translates
  resolved keys into `{model_spec, llm_opts}` pairs for ReqLLM.

  Covers standard providers (Anthropic, OpenRouter), Codex (ChatGPT OAuth),
  and OAuth transformation options.
  """
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.ResolvedKey

  describe "to_llm_args/2 for standard Anthropic key" do
    test "returns model string and base opts" do
      key =
        ResolvedKey.new("anthropic", "sk-ant-123", :env_key, "anthropic:claude-sonnet-4-5")

      {model_spec, llm_opts} = ResolvedKey.to_llm_args(key, max_tokens: 16_384)

      assert model_spec == "anthropic:claude-sonnet-4-5"
      assert Keyword.get(llm_opts, :api_key) == "sk-ant-123"
      assert Keyword.get(llm_opts, :max_tokens) == 16_384
      assert Keyword.get(llm_opts, :oauth_mode) == false
      assert Keyword.get(llm_opts, :requires_mcp_prefix) == false
      assert Keyword.get(llm_opts, :identity_override) == nil
      # No Codex-specific fields
      refute Keyword.has_key?(llm_opts, :base_url)
      refute Keyword.has_key?(llm_opts, :extra_headers)
    end
  end

  describe "to_llm_args/2 for Anthropic OAuth" do
    test "returns model string with OAuth transformation opts" do
      key =
        ResolvedKey.new(
          "anthropic",
          "oauth-access-token",
          :oauth_token,
          "anthropic:claude-sonnet-4-5",
          requires_mcp_prefix: true,
          identity_override: "You are Claude Code",
          oauth_mode: true
        )

      {model_spec, llm_opts} = ResolvedKey.to_llm_args(key, max_tokens: 16_384)

      assert model_spec == "anthropic:claude-sonnet-4-5"
      assert Keyword.get(llm_opts, :api_key) == "oauth-access-token"
      assert Keyword.get(llm_opts, :oauth_mode) == true
      assert Keyword.get(llm_opts, :requires_mcp_prefix) == true
      assert Keyword.get(llm_opts, :identity_override) == "You are Claude Code"
      assert Keyword.get(llm_opts, :max_tokens) == 16_384
    end
  end

  describe "to_llm_args/2 for OpenRouter key" do
    test "returns model string and base opts" do
      key =
        ResolvedKey.new("openrouter", "sk-or-456", :user_key, "openrouter:openai/gpt-5.1-codex")

      {model_spec, llm_opts} = ResolvedKey.to_llm_args(key, max_tokens: 16_384)

      assert model_spec == "openrouter:openai/gpt-5.1-codex"
      assert Keyword.get(llm_opts, :api_key) == "sk-or-456"
      assert Keyword.get(llm_opts, :max_tokens) == 16_384
      assert Keyword.get(llm_opts, :oauth_mode) == false
    end
  end

  describe "to_llm_args/2 for Codex (ChatGPT OAuth)" do
    test "patches base_url, headers, strips max_tokens, forces store:false" do
      key =
        ResolvedKey.new("openai", "chatgpt-access-token", :oauth_token, "openai:gpt-5.3-codex",
          oauth_mode: true,
          chatgpt_account_id: "acc-789",
          codex_endpoint: "https://chatgpt.com/backend-api/codex/responses"
        )

      {model_spec, llm_opts} = ResolvedKey.to_llm_args(key, max_tokens: 16_384)

      # Model spec is resolved through Codex — either an LLMDB struct or string
      case model_spec do
        %{id: id} -> assert id == "gpt-5.3-codex"
        string when is_binary(string) -> assert string =~ "codex"
      end

      # Codex-specific patches
      assert Keyword.get(llm_opts, :base_url) == "https://chatgpt.com/backend-api/codex"
      assert Keyword.get(llm_opts, :extra_headers) == [{"ChatGPT-Account-Id", "acc-789"}]
      assert Keyword.get(llm_opts, :provider_options) == [store: false]
      assert Keyword.get(llm_opts, :api_key) == "chatgpt-access-token"
      # max_tokens is stripped for Codex
      refute Keyword.has_key?(llm_opts, :max_tokens)
    end

    test "normalizes codex-5.3 alias before resolution" do
      key =
        ResolvedKey.new("openai", "token", :oauth_token, "openai:codex-5.3",
          oauth_mode: true,
          codex_endpoint: "https://chatgpt.com/backend-api/codex/responses"
        )

      {model_spec, _llm_opts} = ResolvedKey.to_llm_args(key)

      # The alias should be normalized to gpt-5.3-codex
      case model_spec do
        %{id: id} -> assert id == "gpt-5.3-codex"
        string when is_binary(string) -> assert string == "openai:gpt-5.3-codex"
      end
    end

    test "handles nil chatgpt_account_id" do
      key =
        ResolvedKey.new("openai", "token", :oauth_token, "openai:gpt-5.2-codex",
          oauth_mode: true,
          codex_endpoint: "https://chatgpt.com/backend-api/codex/responses"
        )

      {_model_spec, llm_opts} = ResolvedKey.to_llm_args(key)

      assert Keyword.get(llm_opts, :extra_headers) == []
    end
  end

  describe "to_llm_args/2 extra_opts merging" do
    test "caller opts are merged into base opts" do
      key = ResolvedKey.new("anthropic", "sk-123", :env_key, "anthropic:claude-sonnet-4-5")

      {_model_spec, llm_opts} =
        ResolvedKey.to_llm_args(key, max_tokens: 8_192, temperature: 0.7)

      assert Keyword.get(llm_opts, :max_tokens) == 8_192
      assert Keyword.get(llm_opts, :temperature) == 0.7
    end

    test "returns default opts when no extra_opts provided" do
      key = ResolvedKey.new("openrouter", "sk-or", :user_key, "openrouter:model")

      {_model_spec, llm_opts} = ResolvedKey.to_llm_args(key)

      assert Keyword.get(llm_opts, :api_key) == "sk-or"
      assert Keyword.get(llm_opts, :oauth_mode) == false
    end
  end
end
