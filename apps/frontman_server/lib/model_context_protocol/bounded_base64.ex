defmodule ModelContextProtocol.BoundedBase64 do
  @moduledoc false

  @spec decode(String.t(), non_neg_integer()) :: {:ok, binary()} | {:error, :invalid | :too_large}
  def decode(value, max_bytes)
      when is_binary(value) and is_integer(max_bytes) and max_bytes >= 0 do
    case decoded_size(value) do
      {:ok, size} when size <= max_bytes -> decode_canonical(value)
      {:ok, _size} -> {:error, :too_large}
      :error -> {:error, :invalid}
    end
  end

  defp decoded_size(value) do
    size = byte_size(value)

    case rem(size, 4) do
      0 -> {:ok, div(size, 4) * 3 - padding_bytes(value)}
      _remainder -> :error
    end
  end

  defp padding_bytes(<<>>), do: 0

  defp padding_bytes(value) do
    suffix_size = min(byte_size(value), 2)
    suffix = binary_part(value, byte_size(value) - suffix_size, suffix_size)

    case suffix do
      "==" -> 2
      <<_byte, "=">> -> 1
      _suffix -> 0
    end
  end

  defp decode_canonical(value) do
    case Base.decode64(value) do
      {:ok, decoded} -> canonical_decoded(value, decoded)
      :error -> {:error, :invalid}
    end
  end

  defp canonical_decoded(value, decoded) do
    case Base.encode64(decoded) do
      ^value -> {:ok, decoded}
      _noncanonical -> {:error, :invalid}
    end
  end
end
