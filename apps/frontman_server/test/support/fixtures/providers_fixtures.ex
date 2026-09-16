defmodule FrontmanServer.ProvidersFixtures do
  @moduledoc "Test fixtures for the Providers context."

  use Boundary,
    top_level?: true,
    check: [in: false, out: false]

  @doc """
  Builds a minimal PNG binary with the given dimensions.
  Only enough structure for `Image.check_dimensions/2` to parse.
  """
  def png_fixture(width, height) do
    <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
      <<0::32>> <> "IHDR" <> <<width::32, height::32>> <> <<0::8>>
  end
end
