defmodule FrontmanServer.ChangesetSanitizer do
  import Ecto.Changeset

  def strip_null_bytes(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      value -> put_change(changeset, field, do_strip(value))
    end
  end

  def strip_null_bytes_from_value(value), do: do_strip(value)

  defp do_strip(value) when is_binary(value) do
    :binary.replace(value, <<0>>, <<>>, [:global])
  end

  defp do_strip(%module{} = value) do
    value
    |> Map.from_struct()
    |> Map.new(fn {k, v} -> {k, do_strip(v)} end)
    |> then(&struct!(module, &1))
  end

  defp do_strip(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {do_strip(k), do_strip(v)} end)
  end

  defp do_strip(value) when is_list(value), do: Enum.map(value, &do_strip/1)

  defp do_strip(value), do: value

  def validate_json_encodable(changeset, field) do
    case get_change(changeset, field) do
      nil ->
        changeset

      value ->
        case Jason.encode(value) do
          {:ok, _} -> changeset
          {:error, _} -> add_error(changeset, field, "contains data that is not JSON-encodable")
        end
    end
  end
end
