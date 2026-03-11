defmodule FrontmanServer.Providers.ImageDimensionIntegrationTest do
  @moduledoc """
  Integration tests verifying that provider-specific image dimension limits
  are correctly looked up from the Registry and applied during execution.

  Tests the chain: Registry.max_image_dimension → Image.check_dimensions/2
  to ensure Anthropic images are checked against 7680px while other providers
  pass through without dimension checking.
  """
  use ExUnit.Case, async: true

  alias FrontmanServer.Image
  alias FrontmanServer.Providers.Registry

  describe "provider-aware image dimension checking" do
    test "Anthropic has a 7680px hard limit" do
      max = Registry.max_image_dimension("anthropic")
      assert max == 7680

      # Image within Anthropic limit
      small_png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<1920::32, 1080::32>> <> <<0::8>>

      assert :ok = Image.check_dimensions(small_png, max)

      # Image exceeding Anthropic limit
      large_png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<9000::32, 1080::32>> <> <<0::8>>

      assert {:too_large, 9000, 1080} = Image.check_dimensions(large_png, max)
    end

    test "OpenRouter has no hard limit (auto-resize)" do
      assert Registry.max_image_dimension("openrouter") == nil
      # nil means no check is performed — images pass through regardless of size
    end

    test "OpenAI has no hard limit" do
      assert Registry.max_image_dimension("openai") == nil
    end

    test "Google has no hard limit" do
      assert Registry.max_image_dimension("google") == nil
    end

    test "dimension check integrates with Registry for each known provider" do
      # This test exercises the actual path used by Execution.maybe_constrain_images:
      # Registry.max_image_dimension(provider) → Image.check_dimensions(data, max)

      oversized_png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<9000::32, 6000::32>> <> <<0::8>>

      for provider <- ["openrouter", "openai", "google", "xai"] do
        # These providers return nil — no dimension check needed
        assert Registry.max_image_dimension(provider) == nil,
               "Expected nil max_image_dimension for #{provider}"
      end

      # Anthropic is the only provider with a hard limit
      max = Registry.max_image_dimension("anthropic")
      assert {:too_large, 9000, 6000} = Image.check_dimensions(oversized_png, max)
    end
  end
end
