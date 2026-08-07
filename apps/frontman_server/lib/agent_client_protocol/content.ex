defmodule AgentClientProtocol.Content do
  @moduledoc "Builders for ACP content blocks."

  alias FrontmanServer.CurrentPageContext
  alias FrontmanServer.Tasks.Interaction

  def from_tool_result(%{"content" => content}) when is_list(content) do
    Enum.map(content, &tool_content/1)
  end

  def from_user_message(%Interaction.UserMessage{} = message) do
    Enum.map(message.messages, &%{"type" => "text", "text" => &1}) ++
      annotation_blocks(message.annotations) ++
      image_blocks(message.images) ++
      CurrentPageContext.to_content_blocks(message.current_page)
  end

  defp annotation_blocks(annotations) do
    annotations
    |> Enum.with_index()
    |> Enum.flat_map(fn {annotation, index} ->
      fields =
        annotation
        |> Jason.encode!()
        |> Jason.decode!()
        |> Map.drop(["annotation_index", "metadata", "screenshot"])
        |> Map.merge(%{"annotation" => true, "annotation_index" => index})

      metadata =
        (annotation.metadata || %{})
        |> Map.merge(fields)
        |> reject_nils()

      {uri, text} = annotation_uri_and_text(annotation)

      annotation_resource =
        resource(metadata, %{
          "uri" => uri,
          "mimeType" => "text/plain",
          "text" => text
        })

      [annotation_resource | annotation_screenshot(annotation, index)]
    end)
  end

  defp annotation_uri_and_text(%{file: file, line: line, column: column, tag_name: tag_name})
       when is_binary(file) do
    {"file://#{file}:#{line}:#{column}",
     "Annotated element: <#{tag_name}> at #{file}:#{line}:#{column}"}
  end

  defp annotation_uri_and_text(%{
         metadata: %{
           "elementor" => %{"element_id" => element_id, "edit_hint" => edit_hint} = elementor
         },
         tag_name: tag_name
       }) do
    uri =
      case elementor["post_id"] do
        post_id when is_integer(post_id) ->
          "elementor://post/#{post_id}/element/#{element_id}"

        nil ->
          "elementor://element/#{element_id}"
      end

    detail =
      case elementor do
        %{"element_type" => "widget", "widget_type" => widget_type}
        when is_binary(widget_type) ->
          "widget #{widget_type}"

        %{"element_type" => element_type} when is_binary(element_type) ->
          element_type

        _ ->
          tag_name
      end

    {uri, "Annotated Elementor element: <#{tag_name}> #{detail} (#{edit_hint})"}
  end

  defp annotation_uri_and_text(%{selector: selector, tag_name: tag_name})
       when is_binary(selector) do
    {"selector://#{selector}", "Annotated element: <#{tag_name}> matching #{selector}"}
  end

  defp annotation_uri_and_text(%{tag_name: tag_name}) do
    {"element://#{tag_name}", "Annotated element: <#{tag_name}>"}
  end

  defp annotation_screenshot(%{screenshot: nil}, _index), do: []

  defp annotation_screenshot(annotation, index) do
    [
      resource(
        %{
          "annotation_screenshot" => true,
          "annotation_index" => index,
          "annotation_id" => annotation.annotation_id
        },
        %{
          "uri" => "annotation://#{annotation.annotation_id}/screenshot",
          "mimeType" => annotation.screenshot.mime_type,
          "blob" => annotation.screenshot.blob
        }
      )
    ]
  end

  defp image_blocks(images) do
    Enum.map(images, fn image ->
      resource(
        %{"user_image" => true, "filename" => image.filename},
        %{
          "uri" => image.uri || "attachment://#{image.filename}",
          "mimeType" => image.mime_type,
          "blob" => image.blob
        }
      )
    end)
  end

  defp resource(metadata, content) do
    %{"type" => "resource", "_meta" => metadata, "resource" => content}
  end

  defp tool_content(%{"type" => "text", "text" => text} = content) when is_binary(text),
    do: %{"type" => "content", "content" => content}

  defp tool_content(%{"type" => type, "data" => data, "mimeType" => mime_type} = content)
       when type in ["image", "audio"] and is_binary(data) and is_binary(mime_type),
       do: %{"type" => "content", "content" => content}

  defp tool_content(%{"type" => "resource_link", "name" => name, "uri" => uri} = content)
       when is_binary(name) and is_binary(uri),
       do: %{"type" => "content", "content" => content}

  defp tool_content(
         %{"type" => "resource", "resource" => %{"uri" => uri, "text" => text}} = content
       )
       when is_binary(uri) and is_binary(text),
       do: %{"type" => "content", "content" => content}

  defp tool_content(
         %{"type" => "resource", "resource" => %{"uri" => uri, "blob" => blob}} = content
       )
       when is_binary(uri) and is_binary(blob),
       do: %{"type" => "content", "content" => content}

  defp reject_nils(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
end
