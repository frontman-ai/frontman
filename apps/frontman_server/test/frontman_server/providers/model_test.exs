defmodule FrontmanServer.Providers.ModelTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.Model

  describe "parse/1" do
    test "returns error for strings without colon" do
      assert :error = Model.parse("model-without-provider")
    end

    test "returns error for empty provider" do
      assert :error = Model.parse(":model-without-provider")
    end

    test "returns error for empty name" do
      assert :error = Model.parse("openrouter:")
    end

    test "returns error for non-string input" do
      assert :error = Model.parse(nil)
      assert :error = Model.parse(123)
    end

    test "preserves slashes in OpenRouter model names" do
      assert {:ok, model} = Model.parse("openrouter:anthropic/claude-sonnet-4.5")
      assert model.name == "anthropic/claude-sonnet-4.5"
    end

    test "only splits on first colon" do
      assert {:ok, model} = Model.parse("provider:name:with:colons")
      assert model.provider == "provider"
      assert model.name == "name:with:colons"
    end
  end

  describe "from_client_params/1" do
    test "returns error for empty provider" do
      assert :error = Model.from_client_params(%{"provider" => "", "value" => "gpt-5.5"})
    end

    test "returns error for empty value" do
      assert :error = Model.from_client_params(%{"provider" => "openrouter", "value" => ""})
    end

    test "returns error for missing keys" do
      assert :error = Model.from_client_params(%{"provider" => "openrouter"})
      assert :error = Model.from_client_params(%{"value" => "gpt-5.5"})
    end

    test "returns error for nil" do
      assert :error = Model.from_client_params(nil)
    end
  end

  describe "roundtrip" do
    test "parse -> to_string is identity" do
      original = "openrouter:openai/gpt-5.5"
      {:ok, model} = Model.parse(original)
      assert Model.to_string(model) == original
    end

    test "from_client_params -> to_client_params is identity" do
      original = %{provider: "anthropic", value: "claude-sonnet-4-5"}
      {:ok, model} = Model.from_client_params(original)
      result = Model.to_client_params(model)
      assert result == original
    end

    test "parse roundtrip with slashes" do
      original = "openrouter:anthropic/claude-opus-4.6"
      {:ok, model} = Model.parse(original)
      assert Model.to_string(model) == original
    end
  end

  describe "llm_vendor_name/1" do
    test "extracts vendor from OpenRouter model names" do
      assert Model.llm_vendor_name("openrouter:anthropic/claude-opus-4.6") == "anthropic"
      assert Model.llm_vendor_name("openrouter:openai/gpt-5.5") == "openai"
      assert Model.llm_vendor_name("openrouter:google/gemini-2.5-pro") == "google"
    end

    test "returns provider for direct providers" do
      assert Model.llm_vendor_name("anthropic:claude-sonnet-4-5") == "anthropic"
      assert Model.llm_vendor_name("openai:gpt-5.4") == "openai"
    end

    test "handles LLMDB.Model-style maps with atom provider and binary id" do
      assert Model.llm_vendor_name(%{provider: :openrouter, id: "anthropic/claude-opus-4.6"}) ==
               "anthropic"
    end

    test "returns unknown for nil" do
      assert Model.llm_vendor_name(nil) == "unknown"
    end
  end
end
