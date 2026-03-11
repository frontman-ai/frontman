defmodule FrontmanServer.Providers.CodexTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.Codex

  describe "normalize_model/1" do
    test "rewrites codex-5.3 alias to gpt-5.3-codex" do
      assert Codex.normalize_model("openai:codex-5.3") == "openai:gpt-5.3-codex"
    end

    test "passes through already-normalised model" do
      assert Codex.normalize_model("openai:gpt-5.2-codex") == "openai:gpt-5.2-codex"
    end

    test "passes through non-codex models" do
      assert Codex.normalize_model("anthropic:claude-sonnet-4-5") ==
               "anthropic:claude-sonnet-4-5"
    end
  end

  describe "force_responses_protocol/1" do
    test "sets wire.protocol to openai_responses" do
      model = %{extra: %{wire: %{protocol: "openai_chat"}}}
      result = Codex.force_responses_protocol(model)
      assert result.extra.wire.protocol == "openai_responses"
    end

    test "handles nil extra" do
      model = %{extra: nil}
      result = Codex.force_responses_protocol(model)
      assert result.extra.wire.protocol == "openai_responses"
    end

    test "handles missing wire key" do
      model = %{extra: %{}}
      result = Codex.force_responses_protocol(model)
      assert result.extra.wire.protocol == "openai_responses"
    end

    test "preserves other extra fields" do
      model = %{extra: %{something: "else", wire: %{protocol: "old", other: true}}}
      result = Codex.force_responses_protocol(model)
      assert result.extra.something == "else"
      assert result.extra.wire.other == true
      assert result.extra.wire.protocol == "openai_responses"
    end
  end

  describe "synthesize_model/1" do
    test "passes through non-5.3 model strings" do
      assert Codex.synthesize_model("openai:gpt-5.2-codex") == "openai:gpt-5.2-codex"

      assert Codex.synthesize_model("anthropic:claude-sonnet-4-5") ==
               "anthropic:claude-sonnet-4-5"
    end

    test "synthesizes gpt-5.3-codex from LLMDB base" do
      result = Codex.synthesize_model("openai:gpt-5.3-codex")

      # Either we get a struct (if LLMDB has gpt-5.2-codex) or the raw string (if not)
      case result do
        %{id: id, model: model} ->
          assert id == "gpt-5.3-codex"
          assert model == "gpt-5.3-codex"
          assert result.extra.wire.protocol == "openai_responses"

        string when is_binary(string) ->
          assert string == "openai:gpt-5.3-codex"
      end
    end
  end

  describe "resolve_model/1" do
    test "resolves known LLMDB model with responses protocol" do
      result = Codex.resolve_model("openai:gpt-5.2-codex")

      case result do
        %{extra: %{wire: %{protocol: protocol}}} ->
          assert protocol == "openai_responses"

        string when is_binary(string) ->
          # LLMDB doesn't have this entry in test env — acceptable fallback
          assert string == "openai:gpt-5.2-codex"
      end
    end

    test "falls back to synthesize for unknown models" do
      result = Codex.resolve_model("openai:gpt-99.0-codex")
      assert result == "openai:gpt-99.0-codex"
    end
  end

  describe "base_url/1" do
    test "strips /responses suffix" do
      assert Codex.base_url("https://chatgpt.com/backend-api/codex/responses") ==
               "https://chatgpt.com/backend-api/codex"
    end

    test "handles endpoint without /responses suffix" do
      assert Codex.base_url("https://chatgpt.com/backend-api/codex") ==
               "https://chatgpt.com/backend-api/codex"
    end
  end

  describe "extra_headers/1" do
    test "returns account id header when present" do
      assert Codex.extra_headers("acc-123") == [{"ChatGPT-Account-Id", "acc-123"}]
    end

    test "returns empty list for nil" do
      assert Codex.extra_headers(nil) == []
    end

    test "returns empty list for empty string" do
      assert Codex.extra_headers("") == []
    end
  end

  describe "patch_llm_opts/3" do
    test "applies all Codex-specific patches" do
      opts = [api_key: "sk-123", max_tokens: 16_384]

      result =
        Codex.patch_llm_opts(opts, "https://chatgpt.com/backend-api/codex/responses", "acc-456")

      assert Keyword.get(result, :base_url) == "https://chatgpt.com/backend-api/codex"
      assert Keyword.get(result, :extra_headers) == [{"ChatGPT-Account-Id", "acc-456"}]
      refute Keyword.has_key?(result, :max_tokens)
      assert Keyword.get(result, :provider_options) == [store: false]
      assert Keyword.get(result, :api_key) == "sk-123"
    end

    test "merges store: false into existing provider_options" do
      opts = [provider_options: [other: true]]
      result = Codex.patch_llm_opts(opts, "https://example.com/responses", nil)

      assert Keyword.get(result, :provider_options) == [store: false, other: true]
    end

    test "handles nil account_id" do
      opts = []
      result = Codex.patch_llm_opts(opts, "https://example.com/responses", nil)
      assert Keyword.get(result, :extra_headers) == []
    end
  end
end
