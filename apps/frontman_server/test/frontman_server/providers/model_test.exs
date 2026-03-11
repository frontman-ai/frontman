defmodule FrontmanServer.Providers.ModelTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.Model

  describe "new/2" do
    test "creates a model struct" do
      model = Model.new("openrouter", "openai/gpt-5.1-codex")
      assert model.provider == "openrouter"
      assert model.name == "openai/gpt-5.1-codex"
    end
  end

  describe "to_string/1" do
    test "formats as provider:name" do
      model = Model.new("openrouter", "openai/gpt-5.1-codex")
      assert Model.to_string(model) == "openrouter:openai/gpt-5.1-codex"
    end

    test "works with String.Chars protocol" do
      model = Model.new("anthropic", "claude-sonnet-4-5")
      assert "#{model}" == "anthropic:claude-sonnet-4-5"
    end
  end

  describe "parse/1" do
    test "parses valid provider:name strings" do
      assert {:ok, model} = Model.parse("openrouter:openai/gpt-5.1-codex")
      assert model.provider == "openrouter"
      assert model.name == "openai/gpt-5.1-codex"
    end

    test "handles all known providers" do
      assert {:ok, %Model{provider: "openrouter"}} = Model.parse("openrouter:some-model")
      assert {:ok, %Model{provider: "anthropic"}} = Model.parse("anthropic:claude-sonnet-4-5")
      assert {:ok, %Model{provider: "openai"}} = Model.parse("openai:gpt-5.4")
      assert {:ok, %Model{provider: "google"}} = Model.parse("google:gemini-2.5-pro")
    end

    test "returns error for strings without colon" do
      assert :error = Model.parse("gpt-5.1-codex")
    end

    test "returns error for empty provider" do
      assert :error = Model.parse(":gpt-5.1-codex")
    end

    test "returns error for empty name" do
      assert :error = Model.parse("openrouter:")
    end

    test "returns error for empty string" do
      assert :error = Model.parse("")
    end

    test "returns error for non-string input" do
      assert :error = Model.parse(nil)
      assert :error = Model.parse(123)
    end

    test "preserves slashes in model name" do
      assert {:ok, model} = Model.parse("openrouter:anthropic/claude-sonnet-4.5")
      assert model.name == "anthropic/claude-sonnet-4.5"
    end

    test "only splits on first colon" do
      assert {:ok, model} = Model.parse("provider:name:with:colons")
      assert model.provider == "provider"
      assert model.name == "name:with:colons"
    end
  end

  describe "parse!/1" do
    test "returns model for valid strings" do
      model = Model.parse!("openrouter:openai/gpt-5.1-codex")
      assert model.provider == "openrouter"
    end

    test "raises for invalid strings" do
      assert_raise ArgumentError, fn ->
        Model.parse!("invalid")
      end
    end
  end

  describe "provider_from_string/1" do
    test "extracts provider from prefixed string" do
      assert "openrouter" = Model.provider_from_string("openrouter:openai/gpt-5.1-codex")
      assert "anthropic" = Model.provider_from_string("anthropic:claude-sonnet-4-5")
      assert "openai" = Model.provider_from_string("openai:gpt-5.4")
      assert "google" = Model.provider_from_string("google:gemini-2.5-pro")
    end

    test "falls back to openrouter for unprefixed strings" do
      assert "openrouter" = Model.provider_from_string("gpt-5.1-codex")
    end

    test "falls back to openrouter for empty string" do
      assert "openrouter" = Model.provider_from_string("")
    end
  end

  describe "from_client_params/1 with string keys" do
    test "parses valid client params" do
      params = %{"provider" => "openrouter", "value" => "openai/gpt-5.1-codex"}
      assert {:ok, model} = Model.from_client_params(params)
      assert model.provider == "openrouter"
      assert model.name == "openai/gpt-5.1-codex"
    end

    test "returns error for empty provider" do
      assert :error = Model.from_client_params(%{"provider" => "", "value" => "gpt-5"})
    end

    test "returns error for empty value" do
      assert :error = Model.from_client_params(%{"provider" => "openrouter", "value" => ""})
    end

    test "returns error for missing keys" do
      assert :error = Model.from_client_params(%{"provider" => "openrouter"})
      assert :error = Model.from_client_params(%{"value" => "gpt-5"})
    end

    test "returns error for nil" do
      assert :error = Model.from_client_params(nil)
    end
  end

  describe "from_client_params/1 with atom keys" do
    test "parses valid atom-keyed params" do
      params = %{provider: "openrouter", value: "openai/gpt-5.1-codex"}
      assert {:ok, model} = Model.from_client_params(params)
      assert model.provider == "openrouter"
      assert model.name == "openai/gpt-5.1-codex"
    end

    test "returns error for empty provider" do
      assert :error = Model.from_client_params(%{provider: "", value: "gpt-5"})
    end

    test "returns error for empty value" do
      assert :error = Model.from_client_params(%{provider: "openrouter", value: ""})
    end
  end

  describe "to_client_params/1" do
    test "converts to client format" do
      model = Model.new("openrouter", "openai/gpt-5.1-codex")
      params = Model.to_client_params(model)
      assert params == %{provider: "openrouter", value: "openai/gpt-5.1-codex"}
    end
  end

  describe "roundtrip" do
    test "parse -> to_string is identity" do
      original = "openrouter:openai/gpt-5.1-codex"
      {:ok, model} = Model.parse(original)
      assert Model.to_string(model) == original
    end

    test "from_client_params -> to_client_params is identity" do
      original = %{provider: "anthropic", value: "claude-sonnet-4-5"}
      {:ok, model} = Model.from_client_params(original)
      result = Model.to_client_params(model)
      assert result == original
    end
  end

  describe "resolve_string/1" do
    test "formats a Model struct" do
      model = Model.new("openai", "gpt-5")
      assert Model.resolve_string(model) == "openai:gpt-5"
    end

    test "parses valid string-keyed client params" do
      params = %{"provider" => "openai", "value" => "gpt-5"}
      assert Model.resolve_string(params) == "openai:gpt-5"
    end

    test "parses valid atom-keyed client params" do
      params = %{provider: "anthropic", value: "claude-sonnet-4-5"}
      assert Model.resolve_string(params) == "anthropic:claude-sonnet-4-5"
    end

    test "returns nil for invalid map" do
      assert Model.resolve_string(%{"foo" => "bar"}) == nil
    end

    test "returns nil for nil" do
      assert Model.resolve_string(nil) == nil
    end

    test "returns nil for non-map, non-struct values" do
      assert Model.resolve_string(42) == nil
      assert Model.resolve_string("just a string") == nil
    end
  end

  describe "llm_vendor_name/1" do
    test "returns vendor from OpenRouter model name" do
      assert Model.llm_vendor_name("openrouter:anthropic/claude-opus-4.6") == "anthropic"
      assert Model.llm_vendor_name("openrouter:openai/gpt-5.1-codex") == "openai"
      assert Model.llm_vendor_name("openrouter:google/gemini-2.5-pro") == "google"
    end

    test "returns provider for direct providers" do
      assert Model.llm_vendor_name("anthropic:claude-sonnet-4-5") == "anthropic"
      assert Model.llm_vendor_name("openai:gpt-5.4") == "openai"
      assert Model.llm_vendor_name("google:gemini-2.5-pro") == "google"
    end

    test "works with Model structs" do
      model = Model.new("openrouter", "anthropic/claude-opus-4.6")
      assert Model.llm_vendor_name(model) == "anthropic"

      model = Model.new("anthropic", "claude-sonnet-4-5")
      assert Model.llm_vendor_name(model) == "anthropic"
    end

    test "handles LLMDB.Model-style maps with atom provider and binary id" do
      # LLMDB.Model structs have atom :openrouter provider but binary id
      assert Model.llm_vendor_name(%{provider: :openrouter, id: "anthropic/claude-opus-4.6"}) ==
               "anthropic"

      assert Model.llm_vendor_name(%{provider: :openrouter, id: "openai/gpt-5.1-codex"}) ==
               "openai"
    end

    test "handles maps with atom provider and atom id" do
      assert Model.llm_vendor_name(%{provider: :openrouter, id: :"anthropic/claude-opus-4.6"}) ==
               "anthropic"
    end

    test "returns unknown for nil" do
      assert Model.llm_vendor_name(nil) == "unknown"
    end
  end

  describe "Inspect protocol" do
    test "formats with #Model<...> prefix" do
      model = Model.new("openrouter", "openai/gpt-5.1-codex")
      assert inspect(model) == "#Model<openrouter:openai/gpt-5.1-codex>"
    end
  end
end
