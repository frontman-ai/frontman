defmodule FrontmanServer.Repo.Migrations.CanonicalizeToolResults do
  use Ecto.Migration

  @metadata_bytes_max 16_384
  @metadata_keys_max 64
  @metadata_key_regex Regex.compile!(
                        "^(?:[A-Za-z](?:[A-Za-z0-9-]*[A-Za-z0-9])?" <>
                          "(?:\\.[A-Za-z](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*\\/)?" <>
                          "(?:[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?)?$"
                      )

  def up do
    %{rows: rows} =
      repo().query!(
        "SELECT id::text, data->'result' FROM interactions WHERE type = 'tool_result'"
      )

    canonical_rows = Enum.map(rows, &canonicalize_row/1)
    invalid_count = Enum.count(canonical_rows, &match?({:error, _id}, &1))

    case invalid_count do
      0 -> Enum.each(canonical_rows, &persist_canonical_result/1)
      count -> raise "Cannot canonicalize #{count} malformed persisted tool results"
    end
  end

  def down, do: :ok

  defp canonicalize_row([id, result]) when is_map(result) do
    result = Map.put_new(result, "resultType", "complete")

    case valid_result?(result) do
      true -> {:ok, id, Map.put(result, "_meta", %{})}
      false -> {:error, id}
    end
  end

  defp canonicalize_row([id, _result]), do: {:error, id}

  defp valid_result?(%{"resultType" => "complete", "content" => content} = result)
       when is_list(content) do
    all_true?([
      Enum.all?(content, &valid_content_block?/1),
      optional_boolean?(result, "isError"),
      optional_metadata?(result, "_meta")
    ])
  end

  defp valid_result?(_result), do: false

  defp valid_content_block?(%{"type" => "text", "text" => text} = block)
       when is_binary(text),
       do: valid_content_block_fields?(block)

  defp valid_content_block?(%{"type" => "image"} = block), do: valid_media_block?(block)
  defp valid_content_block?(%{"type" => "audio"} = block), do: valid_media_block?(block)

  defp valid_content_block?(%{"type" => "resource_link"} = block) do
    all_true?([
      is_binary(block["name"]),
      is_binary(block["uri"]),
      valid_uri?(block["uri"]),
      valid_content_block_fields?(block),
      optional_integer?(block, "size"),
      optional_binary?(block, "title"),
      optional_binary?(block, "description"),
      optional_binary?(block, "mimeType"),
      valid_optional_icons?(block, "icons")
    ])
  end

  defp valid_content_block?(%{"type" => "resource", "resource" => resource} = block)
       when is_map(resource),
       do: all_true?([valid_embedded_resource?(resource), valid_content_block_fields?(block)])

  defp valid_content_block?(_block), do: false

  defp valid_media_block?(block) do
    all_true?([
      is_binary(block["data"]),
      is_binary(block["mimeType"]),
      valid_base64?(block["data"]),
      valid_content_block_fields?(block)
    ])
  end

  defp valid_content_block_fields?(block) do
    all_true?([
      optional_metadata?(block, "_meta"),
      valid_annotations?(Map.get(block, "annotations"))
    ])
  end

  defp valid_embedded_resource?(%{"text" => text} = resource) when is_binary(text) do
    all_true?([
      is_binary(resource["uri"]),
      valid_uri?(resource["uri"]),
      optional_binary?(resource, "mimeType"),
      optional_metadata?(resource, "_meta")
    ])
  end

  defp valid_embedded_resource?(%{"blob" => blob} = resource) when is_binary(blob) do
    all_true?([
      is_binary(resource["uri"]),
      valid_uri?(resource["uri"]),
      valid_base64?(blob),
      optional_binary?(resource, "mimeType"),
      optional_metadata?(resource, "_meta")
    ])
  end

  defp valid_embedded_resource?(_resource), do: false

  defp valid_annotations?(nil), do: true

  defp valid_annotations?(annotations) when is_map(annotations) do
    all_true?([
      optional_audience?(annotations),
      optional_priority?(annotations),
      optional_binary?(annotations, "lastModified")
    ])
  end

  defp valid_annotations?(_annotations), do: false

  defp optional_audience?(annotations) do
    case Map.fetch(annotations, "audience") do
      :error ->
        true

      {:ok, audience} when is_list(audience) ->
        Enum.all?(audience, &(&1 in ["assistant", "user"]))

      {:ok, _audience} ->
        false
    end
  end

  defp optional_priority?(annotations) do
    case Map.fetch(annotations, "priority") do
      :error -> true
      {:ok, priority} when is_number(priority) -> priority_in_range?(priority)
      {:ok, _priority} -> false
    end
  end

  defp optional_boolean?(map, key) do
    case Map.fetch(map, key) do
      :error -> true
      {:ok, value} -> is_boolean(value)
    end
  end

  defp optional_integer?(map, key) do
    case Map.fetch(map, key) do
      :error -> true
      {:ok, value} -> is_integer(value)
    end
  end

  defp optional_binary?(map, key) do
    case Map.fetch(map, key) do
      :error -> true
      {:ok, value} -> is_binary(value)
    end
  end

  defp optional_metadata?(map, key) do
    case Map.fetch(map, key) do
      :error -> true
      {:ok, metadata} -> valid_metadata?(metadata)
    end
  end

  defp valid_metadata?(metadata) when is_map(metadata) do
    all_true?([
      map_size(metadata) <= @metadata_keys_max,
      Enum.all?(Map.keys(metadata), &valid_metadata_key?/1),
      byte_size(Jason.encode!(metadata)) <= @metadata_bytes_max
    ])
  end

  defp valid_metadata?(_metadata), do: false

  defp valid_optional_icons?(map, key) do
    case Map.fetch(map, key) do
      :error -> true
      {:ok, icons} when is_list(icons) -> Enum.all?(icons, &valid_icon?/1)
      {:ok, _icons} -> false
    end
  end

  defp valid_icon?(%{"src" => source} = icon) do
    all_true?([
      is_binary(source),
      valid_uri?(source),
      optional_binary?(icon, "mimeType"),
      optional_string_list?(icon, "sizes"),
      optional_theme?(icon)
    ])
  end

  defp valid_icon?(_icon), do: false

  defp optional_string_list?(map, key) do
    case Map.fetch(map, key) do
      :error -> true
      {:ok, values} when is_list(values) -> Enum.all?(values, &is_binary/1)
      {:ok, _values} -> false
    end
  end

  defp optional_theme?(icon) do
    case Map.fetch(icon, "theme") do
      :error -> true
      {:ok, theme} -> theme in ["dark", "light"]
    end
  end

  defp valid_base64?(value) when is_binary(value) do
    case Base.decode64(value) do
      {:ok, decoded} -> Base.encode64(decoded) == value
      :error -> false
    end
  end

  defp valid_base64?(_value), do: false

  defp valid_uri?(value) when is_binary(value) do
    case URI.new(value) do
      {:ok, %URI{scheme: scheme}} when is_binary(scheme) -> true
      {:ok, %URI{scheme: nil}} -> false
      {:error, _part} -> false
    end
  end

  defp valid_uri?(_value), do: false

  defp valid_metadata_key?(key) when is_binary(key), do: Regex.match?(@metadata_key_regex, key)
  defp valid_metadata_key?(_key), do: false

  defp priority_in_range?(priority), do: Enum.all?([priority >= 0, priority <= 1], & &1)

  defp all_true?(values), do: Enum.all?(values, & &1)

  defp persist_canonical_result({:ok, id, result}) do
    repo().query!(
      "UPDATE interactions SET data = jsonb_set(data, '{result}', $2::jsonb, true) WHERE id::text = $1",
      [id, result]
    )
  end
end
