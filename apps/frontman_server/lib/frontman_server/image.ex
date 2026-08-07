defmodule FrontmanServer.Image do
  @max_dimension 7680

  def check_dimensions(data, max \\ @max_dimension) when is_binary(data) and is_integer(max) do
    case parse_dimensions(data) do
      {:ok, width, height} when width > max or height > max ->
        {:too_large, width, height}

      _ ->
        :ok
    end
  end

  def decode_data_url(data_url) when is_binary(data_url) do
    with [_, mime_type, base64] <- Regex.run(~r/^data:([^;]+);base64,(.+)$/s, data_url),
         {:ok, binary} <- Base.decode64(base64) do
      {:ok, binary, mime_type}
    else
      _ -> :error
    end
  end

  def parse_dimensions(<<0xFF, 0xD8, rest::binary>>), do: jpeg_scan_for_sof(rest)

  def parse_dimensions(
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _length::32, "IHDR", width::32,
          height::32, _::binary>>
      ),
      do: {:ok, width, height}

  def parse_dimensions(<<"GIF8", version, "a", width::16-little, height::16-little, _::binary>>)
      when version == ?7 or version == ?9,
      do: {:ok, width, height}

  def parse_dimensions(
        <<"RIFF", _file_size::32-little, "WEBP", "VP8X", _chunk_size::32-little,
          _flags::32-little, width_minus1::24-little, height_minus1::24-little, _::binary>>
      ),
      do: {:ok, width_minus1 + 1, height_minus1 + 1}

  def parse_dimensions(
        <<"RIFF", _file_size::32-little, "WEBP", "VP8L", _chunk_size::32-little, 0x2F,
          bitfield::32-little, _::binary>>
      ) do
    width = Bitwise.band(bitfield, 0x3FFF) + 1
    height = Bitwise.band(Bitwise.bsr(bitfield, 14), 0x3FFF) + 1
    {:ok, width, height}
  end

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
      <<_::binary-size(^skip), remaining::binary>> -> jpeg_scan_for_sof(remaining)
      _ -> :unknown
    end
  end

  defp jpeg_scan_for_sof(<<_, rest::binary>>), do: jpeg_scan_for_sof(rest)
end
