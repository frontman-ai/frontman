# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

alias AgentClientProtocol, as: ACP
alias FrontmanServer.Tasks.Interaction
alias FrontmanServerWeb.ACPHistory

defimpl ACPHistory, for: Interaction.UserMessage do
  @moduledoc """
  Reconstructs the original ACP content blocks from stored UserMessage fields
  and replays them as `user_message_chunk` notifications.

  This is the inverse of `Interaction.UserMessage.new/1` which extracts fields
  from incoming content blocks.
  """

  def to_history_items(%Interaction.UserMessage{} = msg, session_id) do
    blocks =
      text_blocks(msg.messages) ++
        annotation_blocks(msg.annotations) ++
        image_blocks(msg.images) ++
        current_page_blocks(msg.current_page)

    Enum.map(blocks, &ACP.build_user_message_chunk_notification(session_id, &1, msg.timestamp))
  end

  defp text_blocks(messages), do: Enum.map(messages, &%{"type" => "text", "text" => &1})

  defp annotation_blocks(annotations) do
    annotations
    |> Enum.with_index()
    |> Enum.flat_map(fn {ann, index} ->
      meta =
        (ann.metadata || %{})
        |> Map.merge(%{
          "annotation" => true,
          "annotation_index" => index,
          "annotation_id" => ann.annotation_id,
          "tag_name" => ann.tag_name,
          "comment" => ann.comment,
          "file" => ann.file,
          "line" => ann.line,
          "column" => ann.column,
          "component_name" => ann.component_name,
          "component_props" => ann.component_props,
          "parent" => encode_parent(ann.parent),
          "css_classes" => ann.css_classes,
          "nearby_text" => ann.nearby_text,
          "bounding_box" => encode_bounding_box(ann.bounding_box)
        })
        |> reject_nils()

      uri =
        if is_binary(ann.file),
          do: "file://#{ann.file}:#{ann.line}:#{ann.column}",
          else: "element://#{ann.tag_name}"

      text_block = %{
        "type" => "resource",
        "resource" => %{
          "_meta" => meta,
          "resource" => %{
            "uri" => uri,
            "mimeType" => "text/plain",
            "text" => "Annotated element: <#{ann.tag_name}>"
          }
        }
      }

      case ann.screenshot do
        %{blob: blob, mime_type: mime} ->
          screenshot_block = %{
            "type" => "resource",
            "resource" => %{
              "_meta" => %{
                "annotation_screenshot" => true,
                "annotation_index" => index,
                "annotation_id" => ann.annotation_id
              },
              "resource" => %{
                "uri" => "annotation://#{ann.annotation_id}/screenshot",
                "mimeType" => mime,
                "blob" => blob
              }
            }
          }

          [text_block, screenshot_block]

        nil ->
          [text_block]
      end
    end)
  end

  defp image_blocks(images) do
    Enum.map(images, fn img ->
      %{
        "type" => "resource",
        "resource" => %{
          "_meta" => %{"user_image" => true, "filename" => img.filename},
          "resource" => %{
            "uri" => img.uri || "attachment://#{img.filename}",
            "mimeType" => img.mime_type,
            "blob" => img.blob
          }
        }
      }
    end)
  end

  defp current_page_blocks(nil), do: []

  defp current_page_blocks(page) do
    meta =
      %{
        "current_page" => true,
        "url" => page.url,
        "viewport_width" => page.viewport_width,
        "viewport_height" => page.viewport_height,
        "device_pixel_ratio" => page.device_pixel_ratio,
        "title" => page.title,
        "color_scheme" => page.color_scheme,
        "scroll_y" => page.scroll_y
      }
      |> reject_nils()

    [
      %{
        "type" => "resource",
        "resource" => %{
          "_meta" => meta,
          "resource" => %{
            "uri" => "page://#{page.url}",
            "mimeType" => "text/plain",
            "text" => "Current page: #{page.url}"
          }
        }
      }
    ]
  end

  defp encode_bounding_box(nil), do: nil

  defp encode_bounding_box(%{x: x, y: y, width: w, height: h}),
    do: %{"x" => x, "y" => y, "width" => w, "height" => h}

  defp encode_parent(nil), do: nil

  defp encode_parent(%{file: f, line: l, column: c} = p) do
    %{
      "file" => f,
      "line" => l,
      "column" => c,
      "component_name" => p.component_name,
      "component_props" => p.component_props,
      "parent" => encode_parent(p.parent)
    }
    |> reject_nils()
  end

  defp reject_nils(map), do: Map.reject(map, fn {_, v} -> is_nil(v) end)
end

defimpl ACPHistory, for: Interaction.AgentResponse do
  def to_history_items(
        %Interaction.AgentResponse{content: content, timestamp: timestamp},
        session_id
      ) do
    # Per ACP spec: only agent_message_chunk exists (no start/end markers)
    # Client's LoadComplete handler will finalize any streaming messages
    [ACP.build_agent_message_chunk_notification(session_id, content, timestamp)]
  end
end

defimpl ACPHistory, for: Interaction.ToolCall do
  def to_history_items(
        %Interaction.ToolCall{
          tool_call_id: tool_call_id,
          tool_name: tool_name,
          arguments: arguments,
          timestamp: timestamp
        },
        session_id
      ) do
    args_content = ACP.Content.from_tool_result(arguments)

    [
      ACP.tool_call_create(session_id, tool_call_id, tool_name, "other", timestamp),
      ACP.tool_call_update(session_id, tool_call_id, ACP.tool_call_status_pending(), args_content)
    ]
  end
end

defimpl ACPHistory, for: Interaction.ToolResult do
  def to_history_items(
        %Interaction.ToolResult{tool_call_id: tool_call_id, result: result, is_error: is_error},
        session_id
      ) do
    status =
      if is_error, do: ACP.tool_call_status_failed(), else: ACP.tool_call_status_completed()

    result_content = ACP.Content.from_tool_result(result)

    [ACP.tool_call_update(session_id, tool_call_id, status, result_content)]
  end
end

defimpl ACPHistory, for: Interaction.AgentSpawned do
  def to_history_items(%Interaction.AgentSpawned{}, _session_id), do: []
end

defimpl ACPHistory, for: Interaction.AgentCompleted do
  def to_history_items(%Interaction.AgentCompleted{}, _session_id), do: []
end

defimpl ACPHistory, for: Interaction.AgentError do
  def to_history_items(
        %Interaction.AgentError{error: error, category: category, timestamp: timestamp},
        session_id
      ) do
    # Replay errors as sessionUpdate: "error" notifications so the client
    # renders them the same as live agent errors.
    [ACP.build_error_notification(session_id, error, timestamp, category: category)]
  end
end

defimpl ACPHistory, for: Interaction.AgentPaused do
  # Pause state is communicated via task status, not as a history item.
  def to_history_items(%Interaction.AgentPaused{}, _session_id), do: []
end

defimpl ACPHistory, for: Interaction.AgentRetry do
  def to_history_items(%Interaction.AgentRetry{}, _session_id), do: []
end

defimpl ACPHistory, for: Interaction.DiscoveredProjectRule do
  def to_history_items(%Interaction.DiscoveredProjectRule{}, _session_id), do: []
end

defimpl ACPHistory, for: Interaction.DiscoveredProjectStructure do
  def to_history_items(%Interaction.DiscoveredProjectStructure{}, _session_id), do: []
end
