defmodule FrontmanServer.Tasks.CanonicalToolResult do
  alias FrontmanServer.Image
  alias FrontmanServer.JSONSchema
  alias ModelContextProtocol.BoundedBase64
  alias SwarmAi.Message.ContentPart

  @max_content_blocks 64
  @max_media_bytes 8_388_608
  @max_embedded_text_bytes 8_388_608
  @max_image_dimension 7_680
  @mime_type ~r/^[A-Za-z0-9!#$%&'*+.^_`|~-]+\/[A-Za-z0-9!#$%&'*+.^_`|~-]+$/

  @spec canonicalize(map(), map() | nil) ::
          {:ok, map()} | {:error, :invalid_call_tool_result}
  def canonicalize(result, output_schema \\ nil)

  def canonicalize(result, output_schema) when is_map(result) do
    with :ok <- ModelContextProtocol.validate_tool_result(result),
         :ok <- validate_content(result["content"]),
         :ok <- validate_structured_content(result, output_schema) do
      {:ok, Map.put(result, "_meta", %{})}
    else
      {:error, _reason} -> {:error, :invalid_call_tool_result}
    end
  end

  @spec error?(map()) :: boolean()
  def error?(%{"isError" => true}), do: true
  def error?(%{}), do: false

  @spec to_swarm_content(map()) :: [ContentPart.t()]
  def to_swarm_content(%{"content" => content}) when is_list(content) do
    Enum.map(content, &to_swarm_content_part/1)
  end

  defp to_swarm_content_part(%{"type" => "text", "text" => text}) do
    ContentPart.text(text)
  end

  defp to_swarm_content_part(%{
         "type" => "image",
         "data" => data,
         "mimeType" => mime_type
       }) do
    ContentPart.image(Base.decode64!(data), mime_type)
  end

  defp to_swarm_content_part(%{"type" => "audio", "mimeType" => mime_type}) do
    ContentPart.text("[audio: #{mime_type}, data omitted]")
  end

  defp to_swarm_content_part(%{
         "type" => "resource_link",
         "name" => name,
         "uri" => uri
       }) do
    ContentPart.text("[resource link: #{name} (#{uri})]")
  end

  defp to_swarm_content_part(%{
         "type" => "resource",
         "resource" => %{"uri" => uri, "text" => text}
       }) do
    ContentPart.text("[resource: #{uri}]\n#{text}")
  end

  defp to_swarm_content_part(%{
         "type" => "resource",
         "resource" => %{"uri" => uri, "blob" => _blob} = resource
       }) do
    mime_type = Map.get(resource, "mimeType", "application/octet-stream")
    ContentPart.text("[resource: #{uri}, #{mime_type}, binary data omitted]")
  end

  defp validate_content(content) when length(content) <= @max_content_blocks do
    content
    |> Enum.reduce_while({:ok, 0}, fn block, {:ok, media_bytes} ->
      case validate_content_block(block, media_bytes) do
        {:ok, next_media_bytes} -> {:cont, {:ok, next_media_bytes}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> content_validation_result()
  end

  defp validate_content(_content), do: {:error, :content_block_limit_exceeded}

  defp content_validation_result({:ok, _media_bytes}), do: :ok
  defp content_validation_result({:error, _reason} = error), do: error

  defp validate_content_block(%{"type" => "image"} = block, media_bytes) do
    with :ok <- validate_mime_type(block["mimeType"], "image/"),
         {:ok, decoded} <- BoundedBase64.decode(block["data"], @max_media_bytes),
         :ok <- validate_image_dimensions(decoded) do
      add_media_bytes(media_bytes, byte_size(decoded))
    end
  end

  defp validate_content_block(%{"type" => "audio"} = block, media_bytes) do
    with :ok <- validate_mime_type(block["mimeType"], "audio/"),
         {:ok, decoded} <- BoundedBase64.decode(block["data"], @max_media_bytes) do
      add_media_bytes(media_bytes, byte_size(decoded))
    end
  end

  defp validate_content_block(
         %{"type" => "resource", "resource" => %{"blob" => blob} = resource},
         media_bytes
       ) do
    with :ok <- validate_optional_mime_type(resource["mimeType"]),
         {:ok, decoded} <- BoundedBase64.decode(blob, @max_media_bytes) do
      add_media_bytes(media_bytes, byte_size(decoded))
    end
  end

  defp validate_content_block(
         %{"type" => "resource", "resource" => %{"text" => text} = resource},
         media_bytes
       ) do
    with :ok <- validate_optional_mime_type(resource["mimeType"]),
         true <- byte_size(text) <= @max_embedded_text_bytes do
      {:ok, media_bytes}
    else
      false -> {:error, :embedded_text_limit_exceeded}
      {:error, _reason} = error -> error
    end
  end

  defp validate_content_block(%{"mimeType" => mime_type}, media_bytes) do
    case validate_mime_type_value(mime_type) do
      :ok -> {:ok, media_bytes}
      {:error, _reason} = error -> error
    end
  end

  defp validate_content_block(_block, media_bytes), do: {:ok, media_bytes}

  defp validate_mime_type(mime_type, prefix) do
    with :ok <- validate_mime_type_value(mime_type),
         true <- String.starts_with?(String.downcase(mime_type), prefix) do
      :ok
    else
      false -> {:error, :invalid_mime_type}
      {:error, _reason} = error -> error
    end
  end

  defp validate_optional_mime_type(nil), do: :ok
  defp validate_optional_mime_type(mime_type), do: validate_mime_type_value(mime_type)

  defp validate_mime_type_value(mime_type) when is_binary(mime_type) do
    case Regex.match?(@mime_type, mime_type) do
      true -> :ok
      false -> {:error, :invalid_mime_type}
    end
  end

  defp validate_mime_type_value(_mime_type), do: {:error, :invalid_mime_type}

  defp validate_image_dimensions(decoded) do
    case Image.check_dimensions(decoded, @max_image_dimension) do
      :ok -> :ok
      {:too_large, _width, _height} -> {:error, :image_dimension_limit_exceeded}
    end
  end

  defp add_media_bytes(current, added) when current <= @max_media_bytes - added,
    do: {:ok, current + added}

  defp add_media_bytes(_current, _added), do: {:error, :media_limit_exceeded}

  defp validate_structured_content(_result, nil), do: :ok

  defp validate_structured_content(result, output_schema) when is_map(output_schema) do
    case Map.fetch(result, "structuredContent") do
      {:ok, value} -> JSONSchema.validate(output_schema, value)
      :error -> {:error, :missing_structured_content}
    end
  end
end
