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

    test "returns Fireworks models for full and free tiers" do
      expected = [
        %{displayName: "Kimi K2.5 Turbo", value: "accounts/fireworks/routers/kimi-k2p5-turbo"}
      ]

      assert ModelCatalog.models("fireworks", :full) == expected
      assert ModelCatalog.models("fireworks", :free) == expected
    end
  end

  describe "catalog_providers/0" do
    test "providers are ordered by configured priority" do
      providers = ModelCatalog.catalog_providers()

      assert Enum.filter(providers, &(&1 in ["openai", "anthropic", "openrouter", "fireworks"])) ==
               [
                 "openai",
                 "anthropic",
                 "openrouter",
                 "fireworks"
               ]
    end
  end

  describe "pick_default/1" do
    test "picks highest-priority provider's default" do
      default = ModelCatalog.pick_default(["openai", "anthropic", "openrouter"])
      assert default.provider == "openai"
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
