defmodule FrontmanServer.Providers.ModelCatalogTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.ModelCatalog

  describe "models/2" do
    test "returns full model list for openrouter" do
      models = ModelCatalog.models("openrouter", :full)
      assert is_list(models)
      assert length(models) > 10
      assert Enum.all?(models, &match?(%{displayName: _, value: _}, &1))
    end

    test "returns free model list for openrouter" do
      free = ModelCatalog.models("openrouter", :free)
      full = ModelCatalog.models("openrouter", :full)
      assert length(free) < length(full)
      assert free != []
    end

    test "returns full model list for anthropic" do
      models = ModelCatalog.models("anthropic", :full)
      assert models != []
      assert Enum.any?(models, &(&1.value == "claude-sonnet-4-5"))
    end

    test "returns full model list for openai" do
      models = ModelCatalog.models("openai", :full)
      assert models != []
      assert Enum.any?(models, &String.contains?(&1.value, "codex"))
    end

    test "falls back to full tier when free tier doesn't exist" do
      # Anthropic has no free tier, should return full
      full = ModelCatalog.models("anthropic", :full)
      free_fallback = ModelCatalog.models("anthropic", :free)
      assert full == free_fallback
    end

    test "returns empty list for unknown provider" do
      assert ModelCatalog.models("unknown-provider", :full) == []
    end

    test "defaults to full tier" do
      assert ModelCatalog.models("openrouter") == ModelCatalog.models("openrouter", :full)
    end
  end

  describe "default_model/1" do
    test "returns default for openrouter" do
      default = ModelCatalog.default_model("openrouter")
      assert default.provider == "openrouter"
      assert is_binary(default.value)
    end

    test "returns default for anthropic" do
      default = ModelCatalog.default_model("anthropic")
      assert default.provider == "anthropic"
      assert default.value == "claude-sonnet-4-5"
    end

    test "returns default for openai" do
      default = ModelCatalog.default_model("openai")
      assert default.provider == "openai"
      assert default.value == "gpt-5.4"
    end

    test "returns nil for unknown provider" do
      assert ModelCatalog.default_model("fake") == nil
    end
  end

  describe "provider_entry/2" do
    test "builds entry with id, name, and models" do
      entry = ModelCatalog.provider_entry("anthropic", :full)
      assert entry.id == "anthropic"
      assert is_binary(entry.name)
      assert entry.name != ""
      assert is_list(entry.models)
      assert entry.models != []
    end

    test "uses display name from Registry" do
      entry = ModelCatalog.provider_entry("openai", :full)
      assert entry.name == "ChatGPT Pro/Plus"
    end

    test "respects tier for openrouter" do
      full_entry = ModelCatalog.provider_entry("openrouter", :full)
      free_entry = ModelCatalog.provider_entry("openrouter", :free)
      assert length(full_entry.models) > length(free_entry.models)
    end
  end

  describe "catalog_providers/0" do
    test "returns providers sorted by priority" do
      providers = ModelCatalog.catalog_providers()
      assert is_list(providers)
      assert "openai" in providers
      assert "anthropic" in providers
      assert "openrouter" in providers
    end

    test "openai comes before anthropic before openrouter" do
      providers = ModelCatalog.catalog_providers()
      openai_idx = Enum.find_index(providers, &(&1 == "openai"))
      anthropic_idx = Enum.find_index(providers, &(&1 == "anthropic"))
      openrouter_idx = Enum.find_index(providers, &(&1 == "openrouter"))
      assert openai_idx < anthropic_idx
      assert anthropic_idx < openrouter_idx
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

    test "falls back to openrouter" do
      default = ModelCatalog.pick_default(["openrouter"])
      assert default.provider == "openrouter"
    end

    test "falls back to openrouter default for empty list" do
      default = ModelCatalog.pick_default([])
      assert default.provider == "openrouter"
    end
  end
end
