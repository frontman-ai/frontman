defmodule FrontmanServer.Providers.RegistryTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Providers.Registry

  describe "known?/1" do
    test "is case-insensitive" do
      assert Registry.known?("OpenRouter")
      assert Registry.known?("ANTHROPIC")
      assert Registry.known?("Fireworks")
      assert Registry.known?("fireworks")
      assert Registry.known?("openrouter")
    end
  end

  describe "extract_env_keys/1" do
    test "extracts known keys from metadata" do
      metadata = %{
        "openrouterKeyValue" => "sk-or-123",
        "anthropicKeyValue" => "sk-ant-456",
        "fireworksKeyValue" => "fw-789"
      }

      result = Registry.extract_env_keys(metadata)

      assert result == %{
               "openrouter" => "sk-or-123",
               "anthropic" => "sk-ant-456",
               "fireworks" => "fw-789"
             }
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

    test "extracts nested envApiKey metadata" do
      metadata = %{
        "envApiKey" => %{
          "openrouterKeyValue" => "sk-or-nested",
          "fireworksKeyValue" => "sk-fireworks-nested"
        }
      }

      result = Registry.extract_env_keys(metadata)

      assert result == %{
               "openrouter" => "sk-or-nested",
               "fireworks" => "sk-fireworks-nested"
             }
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
end
