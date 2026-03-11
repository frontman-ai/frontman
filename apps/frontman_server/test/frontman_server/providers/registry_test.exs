defmodule FrontmanServer.Providers.RegistryTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.Registry

  describe "all/0" do
    test "returns a map of all known providers" do
      providers = Registry.all()
      assert is_map(providers)
      assert Map.has_key?(providers, "openrouter")
      assert Map.has_key?(providers, "anthropic")
      assert Map.has_key?(providers, "openai")
      assert Map.has_key?(providers, "google")
      assert Map.has_key?(providers, "xai")
    end

    test "each entry has all required fields" do
      required_keys = [
        :config_key,
        :env_var,
        :env_key_name,
        :display_name,
        :priority,
        :oauth_provider,
        :env_key_param,
        :max_image_dimension
      ]

      for {_provider, entry} <- Registry.all() do
        for key <- required_keys do
          assert Map.has_key?(entry, key), "missing key #{key}"
        end

        assert is_atom(entry.config_key)
        assert is_binary(entry.env_var)
        assert is_binary(entry.display_name)
        assert is_integer(entry.priority)
      end
    end
  end

  describe "known?/1" do
    test "returns true for known providers" do
      assert Registry.known?("openrouter")
      assert Registry.known?("anthropic")
      assert Registry.known?("openai")
      assert Registry.known?("google")
      assert Registry.known?("xai")
    end

    test "returns false for unknown providers" do
      refute Registry.known?("fake-provider")
      refute Registry.known?("")
    end

    test "is case-insensitive" do
      assert Registry.known?("OpenRouter")
      assert Registry.known?("ANTHROPIC")
    end
  end

  describe "config_key/1" do
    test "returns correct config key for each provider" do
      assert Registry.config_key("openrouter") == :openrouter_api_key
      assert Registry.config_key("anthropic") == :anthropic_api_key
      assert Registry.config_key("openai") == :openai_api_key
      assert Registry.config_key("google") == :google_api_key
      assert Registry.config_key("xai") == :xai_api_key
    end

    test "returns nil for unknown provider" do
      assert Registry.config_key("fake") == nil
    end

    test "is case-insensitive" do
      assert Registry.config_key("OpenRouter") == :openrouter_api_key
    end
  end

  describe "env_key_mapping/0" do
    test "maps client metadata keys to provider names" do
      mapping = Registry.env_key_mapping()
      assert mapping["openrouterKeyValue"] == "openrouter"
      assert mapping["anthropicKeyValue"] == "anthropic"
    end

    test "only includes providers with non-nil env_key_name" do
      mapping = Registry.env_key_mapping()

      # openai, google, xai have nil env_key_name
      refute Map.has_key?(mapping, nil)

      for {_key, provider} <- mapping do
        entry = Registry.all()[provider]
        assert is_binary(entry.env_key_name)
      end
    end
  end

  describe "extract_env_keys/1" do
    test "extracts known keys from metadata" do
      metadata = %{
        "openrouterKeyValue" => "sk-or-123",
        "anthropicKeyValue" => "sk-ant-456"
      }

      result = Registry.extract_env_keys(metadata)
      assert result == %{"openrouter" => "sk-or-123", "anthropic" => "sk-ant-456"}
    end

    test "ignores empty string values" do
      metadata = %{"openrouterKeyValue" => "", "anthropicKeyValue" => "sk-ant-456"}
      result = Registry.extract_env_keys(metadata)
      assert result == %{"anthropic" => "sk-ant-456"}
    end

    test "ignores nil values" do
      metadata = %{"openrouterKeyValue" => nil}
      result = Registry.extract_env_keys(metadata)
      assert result == %{}
    end

    test "ignores unknown metadata keys" do
      metadata = %{"unknownKeyValue" => "some-key"}
      result = Registry.extract_env_keys(metadata)
      assert result == %{}
    end

    test "handles nil metadata" do
      assert Registry.extract_env_keys(nil) == %{}
    end

    test "handles empty metadata" do
      assert Registry.extract_env_keys(%{}) == %{}
    end

    test "handles non-map input" do
      assert Registry.extract_env_keys("not a map") == %{}
      assert Registry.extract_env_keys(42) == %{}
    end
  end

  describe "display_name/1" do
    test "returns display name for known providers" do
      assert Registry.display_name("openrouter") == "OpenRouter"
      assert Registry.display_name("anthropic") == "Anthropic (Claude Pro/Max)"
      assert Registry.display_name("openai") == "ChatGPT Pro/Plus"
    end

    test "returns nil for unknown provider" do
      assert Registry.display_name("fake") == nil
    end
  end

  describe "oauth_provider/1" do
    test "returns oauth provider string" do
      assert Registry.oauth_provider("anthropic") == "anthropic"
      assert Registry.oauth_provider("openai") == "chatgpt"
    end

    test "returns nil for providers without OAuth" do
      assert Registry.oauth_provider("openrouter") == nil
      assert Registry.oauth_provider("google") == nil
    end

    test "returns nil for unknown provider" do
      assert Registry.oauth_provider("fake") == nil
    end
  end

  describe "env_key_param/1" do
    test "returns param name for providers with env key params" do
      assert Registry.env_key_param("openrouter") == "hasEnvKey"
      assert Registry.env_key_param("anthropic") == "hasAnthropicEnvKey"
    end

    test "returns nil for providers without env key params" do
      assert Registry.env_key_param("openai") == nil
      assert Registry.env_key_param("google") == nil
    end
  end

  describe "priority/1" do
    test "returns priority for known providers" do
      assert Registry.priority("openai") < Registry.priority("anthropic")
      assert Registry.priority("anthropic") < Registry.priority("openrouter")
    end

    test "returns nil for unknown provider" do
      assert Registry.priority("fake") == nil
    end
  end

  describe "max_image_dimension/1" do
    test "returns dimension limit for anthropic" do
      assert Registry.max_image_dimension("anthropic") == 7680
    end

    test "returns nil for providers without a hard limit" do
      assert Registry.max_image_dimension("openai") == nil
      assert Registry.max_image_dimension("openrouter") == nil
      assert Registry.max_image_dimension("google") == nil
      assert Registry.max_image_dimension("xai") == nil
    end

    test "returns nil for unknown provider" do
      assert Registry.max_image_dimension("fake") == nil
    end

    test "is case-insensitive" do
      assert Registry.max_image_dimension("Anthropic") == 7680
    end
  end

  describe "get_server_api_key/1" do
    test "returns nil for unknown provider" do
      assert Registry.get_server_api_key("fake") == nil
    end

    test "delegates to Application.get_env with the correct config key" do
      # Temporarily set a known key so we don't depend on test env config
      original = Application.get_env(:frontman_server, :openrouter_api_key)
      Application.put_env(:frontman_server, :openrouter_api_key, "test-key-123")

      assert Registry.get_server_api_key("openrouter") == "test-key-123"

      # Restore
      if original,
        do: Application.put_env(:frontman_server, :openrouter_api_key, original),
        else: Application.delete_env(:frontman_server, :openrouter_api_key)
    end

    test "is case-insensitive" do
      assert Registry.get_server_api_key("Anthropic") == Registry.get_server_api_key("anthropic")
    end
  end
end
