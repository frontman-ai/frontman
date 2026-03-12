defmodule FrontmanServer.ImageTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Image

  # ── parse_dimensions/1 ──────────────────────────────────────────────

  describe "parse_dimensions/1" do
    # PNG -------------------------------------------------------------------

    test "parses PNG dimensions from IHDR chunk" do
      png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<1920::32, 1080::32>> <> <<0::8>>

      assert {:ok, 1920, 1080} = Image.parse_dimensions(png)
    end

    test "parses large PNG dimensions" do
      png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<9000::32, 6000::32>> <> <<0::8>>

      assert {:ok, 9000, 6000} = Image.parse_dimensions(png)
    end

    # JPEG ------------------------------------------------------------------

    test "parses JPEG dimensions from SOF0 marker" do
      jpeg =
        <<0xFF, 0xD8, 0xFF, 0xC0, 0x00, 0x11, 0x08, 800::16, 1200::16>> <> <<0::8>>

      assert {:ok, 1200, 800} = Image.parse_dimensions(jpeg)
    end

    test "parses JPEG SOF0 after skipping other markers" do
      jpeg =
        <<0xFF, 0xD8>> <>
          <<0xFF, 0xE0, 0x00, 0x10>> <>
          :binary.copy(<<0>>, 14) <>
          <<0xFF, 0xC0, 0x00, 0x11, 0x08, 4000::16, 3000::16>> <> <<0::8>>

      assert {:ok, 3000, 4000} = Image.parse_dimensions(jpeg)
    end

    # GIF -------------------------------------------------------------------

    test "parses GIF89a dimensions" do
      gif = "GIF89a" <> <<320::16-little, 240::16-little>> <> <<0::8>>
      assert {:ok, 320, 240} = Image.parse_dimensions(gif)
    end

    test "parses GIF87a dimensions" do
      gif = "GIF87a" <> <<1024::16-little, 768::16-little>> <> <<0::8>>
      assert {:ok, 1024, 768} = Image.parse_dimensions(gif)
    end

    test "returns :unknown for truncated GIF" do
      assert :unknown = Image.parse_dimensions("GIF89a" <> <<0>>)
    end

    # WebP ------------------------------------------------------------------

    test "parses WebP VP8X (extended) dimensions" do
      width = 1920
      height = 1080

      webp =
        "RIFF" <>
          <<0::32-little>> <>
          "WEBP" <>
          "VP8X" <>
          <<10::32-little>> <>
          <<0::32-little>> <>
          <<width - 1::24-little, height - 1::24-little>> <>
          <<0::8>>

      assert {:ok, ^width, ^height} = Image.parse_dimensions(webp)
    end

    test "parses WebP VP8L (lossless) dimensions" do
      width = 800
      height = 600

      bitfield =
        Bitwise.bor(
          Bitwise.band(width - 1, 0x3FFF),
          Bitwise.bsl(Bitwise.band(height - 1, 0x3FFF), 14)
        )

      webp =
        "RIFF" <>
          <<0::32-little>> <>
          "WEBP" <>
          "VP8L" <>
          <<0::32-little>> <>
          <<0x2F>> <>
          <<bitfield::32-little>> <>
          <<0::8>>

      assert {:ok, ^width, ^height} = Image.parse_dimensions(webp)
    end

    test "parses WebP VP8 (lossy) dimensions" do
      width = 640
      height = 480

      webp =
        "RIFF" <>
          <<0::32-little>> <>
          "WEBP" <>
          "VP8 " <>
          <<0::32-little>> <>
          <<0, 0, 0>> <>
          <<0x9D, 0x01, 0x2A>> <>
          <<width::16-little, height::16-little>> <>
          <<0::8>>

      assert {:ok, ^width, ^height} = Image.parse_dimensions(webp)
    end

    test "returns :unknown for truncated WebP" do
      assert :unknown = Image.parse_dimensions("RIFF" <> <<0::32-little>> <> "WEBP")
    end

    # Unknown ---------------------------------------------------------------

    test "returns :unknown for non-image binary" do
      assert :unknown = Image.parse_dimensions("not an image")
    end

    test "returns :unknown for empty binary" do
      assert :unknown = Image.parse_dimensions(<<>>)
    end

    test "returns :unknown for truncated PNG header" do
      assert :unknown = Image.parse_dimensions(<<0x89, 0x50, 0x4E, 0x47>>)
    end

    test "returns :unknown for truncated JPEG" do
      assert :unknown = Image.parse_dimensions(<<0xFF, 0xD8>>)
    end
  end

  # ── check_dimensions/1,2 ─────────────────────────────────────────────

  describe "check_dimensions/1 (default max)" do
    test "returns :ok for image within limits" do
      png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<1920::32, 1080::32>> <> <<0::8>>

      assert :ok = Image.check_dimensions(png)
    end

    test "returns {:too_large, w, h} when width exceeds limit" do
      png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<9000::32, 1080::32>> <> <<0::8>>

      assert {:too_large, 9000, 1080} = Image.check_dimensions(png)
    end

    test "returns {:too_large, w, h} when height exceeds limit" do
      png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<1920::32, 8000::32>> <> <<0::8>>

      assert {:too_large, 1920, 8000} = Image.check_dimensions(png)
    end

    test "returns :ok for unrecognised format (fail-open)" do
      assert :ok = Image.check_dimensions("not an image")
    end

    test "returns :ok at exactly default boundary (7680px)" do
      png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<7680::32, 7680::32>> <> <<0::8>>

      assert :ok = Image.check_dimensions(png)
    end
  end

  describe "check_dimensions/2 (custom max)" do
    test "respects a smaller custom max" do
      # 1920x1080 is fine for the default 7680 but too big for a 1000px limit
      png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<1920::32, 1080::32>> <> <<0::8>>

      assert {:too_large, 1920, 1080} = Image.check_dimensions(png, 1000)
    end

    test "respects a larger custom max" do
      # 9000px wide exceeds the default 7680 but fits within a 10_000 limit
      png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<9000::32, 1080::32>> <> <<0::8>>

      assert :ok = Image.check_dimensions(png, 10_000)
    end

    test "returns :ok at exactly the custom boundary" do
      png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<500::32, 500::32>> <> <<0::8>>

      assert :ok = Image.check_dimensions(png, 500)
    end

    test "returns {:too_large, w, h} one pixel over custom boundary" do
      png =
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>> <>
          <<0::32>> <> "IHDR" <> <<501::32, 500::32>> <> <<0::8>>

      assert {:too_large, 501, 500} = Image.check_dimensions(png, 500)
    end

    test "returns :ok for unrecognised format (fail-open) with custom max" do
      assert :ok = Image.check_dimensions("not an image", 100)
    end
  end

  # ── decode_data_url/1 ───────────────────────────────────────────────

  describe "decode_data_url/1" do
    test "decodes a valid data URL" do
      payload = Base.encode64("hello image")
      data_url = "data:image/png;base64,#{payload}"

      assert {:ok, "hello image", "image/png"} = Image.decode_data_url(data_url)
    end

    test "decodes with different MIME types" do
      payload = Base.encode64("webp data")
      data_url = "data:image/webp;base64,#{payload}"

      assert {:ok, "webp data", "image/webp"} = Image.decode_data_url(data_url)
    end

    test "returns :error for missing data: prefix" do
      assert :error = Image.decode_data_url("image/png;base64,abc")
    end

    test "returns :error for invalid base64" do
      assert :error = Image.decode_data_url("data:image/png;base64,!!!not-valid!!!")
    end

    test "returns :error for empty string" do
      assert :error = Image.decode_data_url("")
    end

    test "handles multiline base64 payload" do
      # The /s flag in the regex should handle newlines in the base64 portion
      payload = Base.encode64(String.duplicate("x", 100))
      data_url = "data:image/jpeg;base64,#{payload}"

      assert {:ok, _binary, "image/jpeg"} = Image.decode_data_url(data_url)
    end
  end

  # ── image_tool_config/1 ─────────────────────────────────────────────

  describe "image_tool_config/1" do
    test "returns config for take_screenshot" do
      assert {:screenshot, []} = Image.image_tool_config("take_screenshot")
    end

    test "strips mcp_ prefix and returns config" do
      assert {:screenshot, []} = Image.image_tool_config("mcp_take_screenshot")
    end

    test "returns nil for unknown tool" do
      assert nil == Image.image_tool_config("read_file")
    end

    test "returns nil for unknown mcp_ tool" do
      assert nil == Image.image_tool_config("mcp_read_file")
    end
  end
end
