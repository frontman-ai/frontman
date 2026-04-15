defmodule FrontmanServer.Providers.ImageDimensionIntegrationTest do
  @moduledoc """
  Integration tests for Registry.max_image_dimension → Image.check_dimensions.
  """
  use ExUnit.Case, async: true

  import FrontmanServer.ProvidersFixtures

  alias FrontmanServer.Image
  alias FrontmanServer.Providers.Registry

  describe "provider-aware image dimension checking" do
    test "Anthropic enforces 7680px hard limit" do
      max = Registry.max_image_dimension("anthropic")
      assert max == 7680

      assert :ok = Image.check_dimensions(png_fixture(1920, 1080), max)
      assert {:too_large, 9000, 1080} = Image.check_dimensions(png_fixture(9000, 1080), max)
    end

    test "all other providers have no dimension limit" do
      for provider <- ["openrouter", "openai", "fireworks", "google", "xai"] do
        assert Registry.max_image_dimension(provider) == nil,
               "Expected nil max_image_dimension for #{provider}"
      end
    end
  end
end
