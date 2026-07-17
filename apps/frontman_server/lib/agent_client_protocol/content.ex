# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule AgentClientProtocol.Content do
  @moduledoc "Builders for ACP content blocks."

  alias FrontmanServer.CurrentPageContext
  alias FrontmanServer.Tasks.Interaction

  def from_tool_result(%{"content" => content}) when is_list(content) do
    Enum.map(content, fn
      %{"type" => "text", "text" => text} when is_binary(text) ->
        tool_content(text)

      part ->
        part |> Jason.encode!() |> tool_content()
    end)
  end

  def from_tool_result(result) when is_map(result),
    do: [result |> Jason.encode!() |> tool_content()]

  def from_tool_result(result) when is_binary(result), do: [tool_content(result)]
  def from_tool_result(result), do: [result |> inspect() |> tool_content()]

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

  defp tool_content(text) do
    %{"type" => "content", "content" => %{"type" => "text", "text" => text}}
  end

  defp reject_nils(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
end
