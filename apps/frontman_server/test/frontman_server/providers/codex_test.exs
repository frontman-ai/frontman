defmodule FrontmanServer.Providers.CodexTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.Codex
  alias ReqLLM.Providers.OpenAICodex

  describe "normalize_model/1" do
    test "normalizes codex alias to openai_codex model" do
      assert Codex.normalize_model("openai:codex-5.3") == "openai_codex:gpt-5.3-codex"
    end

    test "rewrites openai namespace to openai_codex" do
      assert Codex.normalize_model("openai:gpt-5.2-codex") == "openai_codex:gpt-5.2-codex"
    end

    test "keeps openai_codex models unchanged" do
      assert Codex.normalize_model("openai_codex:gpt-5.3-codex") == "openai_codex:gpt-5.3-codex"
    end
  end

  describe "resolve_model/1" do
    test "returns catalogued openai_codex model" do
      result = Codex.resolve_model("openai_codex:gpt-5.3-codex")
      assert %{provider: :openai_codex, id: "gpt-5.3-codex"} = result
    end

    test "synthesizes explicit model spec when model is uncatalogued" do
      result = Codex.resolve_model("openai_codex:gpt-9.9-codex")

      assert %{provider: :openai_codex, id: "gpt-9.9-codex"} = result
      assert result.model == "gpt-9.9-codex"
      assert result.provider_model_id == "gpt-9.9-codex"
      assert get_in(result.extra, [:wire, :protocol]) == "openai_codex_responses"
    end
  end

  describe "patch_llm_opts/3" do
    test "applies all Codex-specific patches" do
      opts = [api_key: "sk-123", max_tokens: 16_384]

      result =
        Codex.patch_llm_opts(opts, "https://chatgpt.com/backend-api/codex/responses", "acc-456")

      assert Keyword.get(result, :base_url) == "https://chatgpt.com/backend-api/codex"
      assert Keyword.get(result, :chatgpt_account_id) == "acc-456"
      refute Keyword.has_key?(result, :max_tokens)
      assert Keyword.get(result, :provider_options) == [store: false]
      refute Keyword.has_key?(result, :req_http_options)
      assert Keyword.get(result, :api_key) == "sk-123"
    end

    test "preserves provider options while disabling response storage" do
      opts = [api_key: "sk-123", provider_options: [verbosity: :low]]

      result = Codex.patch_llm_opts(opts, "https://example.com/responses", nil)

      provider_options = Keyword.fetch!(result, :provider_options)
      assert Keyword.get(provider_options, :verbosity) == :low
      assert Keyword.get(provider_options, :store) == false
    end

    test "builds Codex requests without previous_response_id from context" do
      opts =
        Codex.patch_llm_opts(
          [auth_mode: :oauth, access_token: "chatgpt-access-token", max_tokens: 16_384],
          "https://chatgpt.com/backend-api/codex/responses",
          "acc-456"
        )

      context =
        ReqLLM.context([
          ReqLLM.Context.assistant("Previous answer", metadata: %{response_id: "resp_prev_123"}),
          ReqLLM.Context.user("Follow up")
        ])

      {:ok, request} =
        OpenAICodex.attach_stream(
          Codex.resolve_model("openai_codex:gpt-5.3-codex"),
          context,
          opts,
          nil
        )

      body = Jason.decode!(request.body)

      refute Map.has_key?(body, "previous_response_id")
      assert body["store"] == false
    end

    test "does not set chatgpt_account_id when missing" do
      opts = [api_key: "sk-123", max_tokens: 16_384]
      result = Codex.patch_llm_opts(opts, "https://example.com/responses", nil)

      refute Keyword.has_key?(result, :chatgpt_account_id)
    end
  end
end
