defmodule Swarm.ToolResult do
  @moduledoc """
  Result of a tool execution, supporting multimodal content (text + images).
  """
  use TypedStruct

  alias Swarm.Message.ContentPart

  typedstruct enforce: true do
    field :id, String.t()
    field :content, [ContentPart.t()]
    field :is_error, boolean(), default: false
  end

  # Tools returning images: {image_field, extra_text_fields}
  @image_tool_configs %{
    "take_screenshot" => {:screenshot, []},
    "get_figma_node" => {:image, [:node]}
  }

  @doc """
  Creates a ToolResult from raw tool output, extracting images for configured tools.
  """
  @spec make(String.t(), String.t(), term(), boolean()) :: t()
  def make(id, tool_name, raw_result, is_error \\ false)

  def make(id, tool_name, raw_result, is_error) when is_map(raw_result) do
    content = extract_content_parts(tool_name, raw_result)
    %__MODULE__{id: id, content: content, is_error: is_error}
  end

  def make(id, _tool_name, raw_result, is_error) when is_binary(raw_result) do
    %__MODULE__{id: id, content: [ContentPart.text(raw_result)], is_error: is_error}
  end

  def make(id, _tool_name, raw_result, is_error) do
    %__MODULE__{id: id, content: [ContentPart.text(encode_json(raw_result))], is_error: is_error}
  end

  defp extract_content_parts(tool_name, result) do
    case extract_image(tool_name, result) do
      {image_binary, mime_type, text_content} ->
        build_multimodal_content(text_content, image_binary, mime_type)

      nil ->
        [ContentPart.text(encode_json(result))]
    end
  end

  defp extract_image(tool_name, result) do
    with {image_field, text_fields} <- Map.get(@image_tool_configs, tool_name),
         data_url when is_binary(data_url) <- get_field(result, image_field),
         {:ok, binary, mime} <- decode_data_url(data_url) do
      {binary, mime, build_text_content(result, text_fields)}
    else
      _ -> nil
    end
  end

  defp build_multimodal_content("", image_binary, mime_type),
    do: [ContentPart.image(image_binary, mime_type)]

  defp build_multimodal_content(text_content, image_binary, mime_type),
    do: [ContentPart.text(text_content), ContentPart.image(image_binary, mime_type)]

  defp build_text_content(result, fields) do
    text_parts =
      Enum.flat_map(fields, fn field ->
        case get_field(result, field) do
          nil -> []
          value -> [format_field(field, value)]
        end
      end)

    error = get_field(result, :error)
    text_parts = if error, do: text_parts ++ ["Error: #{error}"], else: text_parts

    Enum.join(text_parts, "\n\n")
  end

  defp format_field(:node, value), do: "Node data:\n#{encode_json(value)}"
  defp format_field(field, value), do: "#{field}: #{encode_json(value)}"

  defp encode_json(value) when is_binary(value), do: value
  defp encode_json(value), do: Jason.encode!(value)

  defp get_field(map, key) when is_atom(key),
    do: Map.get(map, Atom.to_string(key)) || Map.get(map, key)

  defp get_field(map, key) when is_binary(key),
    do: Map.get(map, key) || Map.get(map, String.to_atom(key))

  defp decode_data_url(data_url) do
    with [_, mime_type, base64] <- Regex.run(~r/^data:([^;]+);base64,(.+)$/s, data_url),
         {:ok, binary} <- Base.decode64(base64) do
      {:ok, binary, mime_type}
    else
      _ -> :error
    end
  end
end
