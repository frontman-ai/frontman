defmodule FrontmanServer.Image do
  @moduledoc """
  Shared image utilities for the FrontmanServer domain.

  Pure functions for image binary inspection, data URL decoding, and
  provider-specific constraint constants. This module has **no dependency**
  on message content part types (`SwarmAi.Message.ContentPart`,
  `ReqLLM.Message.ContentPart`) — callers wrap results in their own types.

  Used by both the Agents and Tasks contexts.
  """

  # Max dimension for Anthropic image inputs (pixels per side).
  # Anthropic hard-rejects > 8000px; we use 7680 for margin.
  # Other providers (OpenAI, OpenRouter, Google) auto-resize.
  @max_dimension 7680

  # Tools whose results contain base64-encoded images.
  # {image_field, extra_text_fields} per canonical tool name (without mcp_ prefix).
  @image_tool_configs %{
    "take_screenshot" => {:screenshot, []}
  }

  # ── Public API ──────────────────────────────────────────────────────

  @doc """
  Returns the image extraction config for a tool, or `nil` if the tool
  does not produce images.

  The canonical name is used (the `mcp_` prefix is stripped automatically).

      iex> FrontmanServer.Image.image_tool_config("take_screenshot")
      {:screenshot, []}

      iex> FrontmanServer.Image.image_tool_config("mcp_take_screenshot")
      {:screenshot, []}

      iex> FrontmanServer.Image.image_tool_config("read_file")
      nil
  """
  @spec image_tool_config(String.t()) :: {atom(), [atom()]} | nil
  def image_tool_config(tool_name) when is_binary(tool_name) do
    canonical = String.replace_prefix(tool_name, "mcp_", "")
    Map.get(@image_tool_configs, canonical)
  end

  @doc """
  Checks whether a binary image exceeds a dimension limit on either axis.

  Returns `:ok` when the image is within limits or the format is
  unrecognised (fail-open). Returns `{:too_large, width, height}` when
  either dimension exceeds the limit.

  The optional second argument overrides the default `max_dimension/0`.
  """
  @spec check_dimensions(binary(), pos_integer()) ::
          :ok | {:too_large, pos_integer(), pos_integer()}
  def check_dimensions(data, max \\ @max_dimension) when is_binary(data) and is_integer(max) do
    case parse_dimensions(data) do
      {:ok, width, height} when width > max or height > max ->
        {:too_large, width, height}

      _ ->
        :ok
    end
  end

  @doc """
  Decodes a `data:<mime>;base64,<payload>` URL into raw binary.

  Returns `{:ok, binary, mime_type}` on success, `:error` on malformed
  input or base64 decode failure.
  """
  @spec decode_data_url(String.t()) :: {:ok, binary(), String.t()} | :error
  def decode_data_url(data_url) when is_binary(data_url) do
    with [_, mime_type, base64] <- Regex.run(~r/^data:([^;]+);base64,(.+)$/s, data_url),
         {:ok, binary} <- Base.decode64(base64) do
      {:ok, binary, mime_type}
    else
      _ -> :error
    end
  end

  @doc """
  Parse image dimensions from binary headers.

  Supports JPEG, PNG, GIF (87a/89a), and WebP (VP8, VP8L, VP8X).
  Returns `{:ok, width, height}` or `:unknown` for unrecognised formats.
  """
  @spec parse_dimensions(binary()) :: {:ok, pos_integer(), pos_integer()} | :unknown

  # JPEG: scan for SOFn marker which contains dimensions
  def parse_dimensions(<<0xFF, 0xD8, rest::binary>>), do: jpeg_scan_for_sof(rest)

  # PNG: IHDR chunk at fixed offset contains width/height as 4-byte big-endian ints
  def parse_dimensions(
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _length::32, "IHDR", width::32,
          height::32, _::binary>>
      ),
      do: {:ok, width, height}

  # GIF87a / GIF89a: width and height as 16-bit little-endian at bytes 6-9
  def parse_dimensions(<<"GIF8", version, "a", width::16-little, height::16-little, _::binary>>)
      when version == ?7 or version == ?9,
      do: {:ok, width, height}

  # WebP VP8X (extended — alpha, animation, ICC, etc.): canvas dims as 24-bit LE + 1
  def parse_dimensions(
        <<"RIFF", _file_size::32-little, "WEBP", "VP8X", _chunk_size::32-little,
          _flags::32-little, width_minus1::24-little, height_minus1::24-little, _::binary>>
      ),
      do: {:ok, width_minus1 + 1, height_minus1 + 1}

  # WebP VP8L (lossless): 0x2F signature byte, then width-1 and height-1 packed
  # into a 32-bit LE bitfield (14 bits each, starting from bit 0)
  def parse_dimensions(
        <<"RIFF", _file_size::32-little, "WEBP", "VP8L", _chunk_size::32-little, 0x2F,
          bitfield::32-little, _::binary>>
      ) do
    width = Bitwise.band(bitfield, 0x3FFF) + 1
    height = Bitwise.band(Bitwise.bsr(bitfield, 14), 0x3FFF) + 1
    {:ok, width, height}
  end

  # WebP VP8 (lossy): 3-byte frame tag + sync code 0x9D012A, then 16-bit LE dims
  # (lower 14 bits are the actual dimension, upper 2 bits are scale factor)
  def parse_dimensions(
        <<"RIFF", _file_size::32-little, "WEBP", "VP8 ", _chunk_size::32-little,
          _frame_tag::binary-size(3), 0x9D, 0x01, 0x2A, width_raw::16-little,
          height_raw::16-little, _::binary>>
      ) do
    width = Bitwise.band(width_raw, 0x3FFF)
    height = Bitwise.band(height_raw, 0x3FFF)
    {:ok, width, height}
  end

  def parse_dimensions(_), do: :unknown

  # ── Private ─────────────────────────────────────────────────────────

  # Scan JPEG markers looking for any SOFn (Start of Frame) marker.
  # SOFn markers are 0xFFC0-0xFFCF except 0xFFC4 (DHT), 0xFFC8 (JPG extension),
  # and 0xFFCC (DAC — Define Arithmetic Conditioning).
  defp jpeg_scan_for_sof(<<>>), do: :unknown

  defp jpeg_scan_for_sof(
         <<0xFF, marker, _length::16, _precision, height::16, width::16, _::binary>>
       )
       when marker >= 0xC0 and marker <= 0xCF and marker != 0xC4 and marker != 0xC8 and
              marker != 0xCC,
       do: {:ok, width, height}

  defp jpeg_scan_for_sof(<<0xFF, marker, length::16, rest::binary>>)
       when marker != 0x00 and marker != 0xFF do
    skip = max(length - 2, 0)

    case rest do
      <<_::binary-size(skip), remaining::binary>> -> jpeg_scan_for_sof(remaining)
      _ -> :unknown
    end
  end

  defp jpeg_scan_for_sof(<<_, rest::binary>>), do: jpeg_scan_for_sof(rest)
end
