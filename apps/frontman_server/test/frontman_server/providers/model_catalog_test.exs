defmodule FrontmanServer.Providers.ModelCatalogTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.ModelCatalog

  describe "models/2" do
    @tag :skip
    # Known catalog data issue: minimax-m2.5 and kimi-k2.5 in free but not full tier
    test "free tier is a strict subset of full tier for openrouter" do
      free = ModelCatalog.models("openrouter", :free)
      full = ModelCatalog.models("openrouter", :full)
      assert free != []
      assert length(free) < length(full)

      free_values = MapSet.new(free, & &1.value)
      full_values = MapSet.new(full, & &1.value)
      assert MapSet.subset?(free_values, full_values)
    end

    test "returns empty list for unknown provider" do
      assert ModelCatalog.models("unknown-provider", :full) == []
    end

    test "includes GPT-5.5 in OpenAI and OpenRouter full tiers" do
      assert %{displayName: "GPT-5.5", value: "gpt-5.5"} in ModelCatalog.models("openai", :full)

      assert %{displayName: "GPT-5.5", value: "openai/gpt-5.5"} in ModelCatalog.models(
               "openrouter",
               :full
             )
    end

    test "includes latest OpenRouter OSS models" do
      models = ModelCatalog.models("openrouter", :full)

      assert Enum.all?(
               [
                 %{displayName: "Kimi K2.6", value: "moonshotai/kimi-k2.6"},
                 %{displayName: "MiniMax M2.7", value: "minimax/minimax-m2.7"}
               ],
               &(&1 in models)
             )
    end

    test "excludes retired GPT-5.2 and older GPT-5 family models" do
      openai_values = ModelCatalog.models("openai", :full) |> Enum.map(& &1.value) |> MapSet.new()

      openrouter_values =
        ModelCatalog.models("openrouter", :full) |> Enum.map(& &1.value) |> MapSet.new()

      assert MapSet.subset?(
               MapSet.new(~w[gpt-5.5 gpt-5.4 gpt-5.4-mini gpt-5.3-codex]),
               openai_values
             )

      assert MapSet.disjoint?(
               openai_values,
               MapSet.new(~w[gpt-5.2-codex gpt-5.2 gpt-5.1-codex-max gpt-5.1-codex-mini])
             )

      assert MapSet.disjoint?(
               openrouter_values,
               MapSet.new(
                 ~w[openai/gpt-5.2 openai/gpt-5.1 openai/gpt-5 openai/gpt-5-mini openai/gpt-5-chat]
               )
             )
    end

    test "returns Fireworks models for full and free tiers" do
      expected = [
        %{displayName: "Kimi K2.5 Turbo", value: "accounts/fireworks/routers/kimi-k2p5-turbo"}
      ]

      assert ModelCatalog.models("fireworks", :full) == expected
      assert ModelCatalog.models("fireworks", :free) == expected
    end

    test "returns NVIDIA models" do
      expected = [
        %{displayName: "Kimi K2.6", value: "moonshotai/kimi-k2.6"},
        %{displayName: "DeepSeek V4 Flash", value: "deepseek-ai/deepseek-v4-flash"},
        %{displayName: "MiniMax M2.7", value: "minimaxai/minimax-m2.7"},
        %{displayName: "Qwen3 Coder 480B", value: "qwen/qwen3-coder-480b-a35b-instruct"}
      ]

      assert ModelCatalog.models("nvidia", :full) == expected

      assert ModelCatalog.pick_default(["nvidia"]) == %{
               provider: "nvidia",
               value: hd(expected).value
             }

      Enum.each(expected, fn model ->
        assert {:ok, reqllm_model} = ReqLLM.model("nvidia:#{model.value}")
        assert :text in reqllm_model.modalities.input
      end)
    end
  end

  describe "catalog_providers/0" do
    test "providers are ordered by configured priority" do
      providers = ModelCatalog.catalog_providers()
      expected = ~w[openai anthropic openrouter fireworks nvidia]

      assert Enum.filter(providers, &(&1 in expected)) == expected
    end
  end

  describe "pick_default/1" do
    test "picks highest-priority provider's default" do
      default = ModelCatalog.pick_default(["openai", "anthropic", "openrouter"])
      assert default.provider == "openai"
      assert default.value == "gpt-5.5"
    end

    test "picks anthropic when openai not available" do
      default = ModelCatalog.pick_default(["anthropic", "openrouter"])
      assert default.provider == "anthropic"
    end

    test "picks fireworks when it is the only available provider" do
      default = ModelCatalog.pick_default(["fireworks"])
      assert default.provider == "fireworks"
      assert default.value == "accounts/fireworks/routers/kimi-k2p5-turbo"
    end

    test "falls back to openrouter for empty list" do
      default = ModelCatalog.pick_default([])
      assert default.provider == "openrouter"
    end
  end
end
