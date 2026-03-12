defmodule FrontmanServer.Providers.CodexTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.Codex

  describe "force_responses_protocol/1" do
    test "handles nil extra without crashing" do
      model = %{extra: nil}
      result = Codex.force_responses_protocol(model)
      assert result.extra.wire.protocol == "openai_responses"
    end

    test "handles missing wire key without crashing" do
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
  end
end
