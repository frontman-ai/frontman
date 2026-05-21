# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.MessageOptimizer.ToolResultImageExpansion do
  @moduledoc """
  Converts image-producing tool result JSON into Swarm image content parts.

  Persisted interactions keep JSON-safe data URLs. The optimizer expands those
  into binary image content parts only at the LLM request boundary.
  """

  alias FrontmanServer.Image
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  @spec run([Message.t()], keyword()) :: [Message.t()]
  def run(messages, _opts \\ []) do
    Enum.map(messages, &expand_tool_image/1)
  end

  defp expand_tool_image(%Message.Tool{name: name, content: content} = msg) do
    with json when is_binary(json) <- text_part(content),
         {:ok, decoded} when is_map(decoded) <- Jason.decode(json),
         {:ok, %{data: data, media_type: media_type}} <-
           decode_tool_image(canonical_tool_name(name), decoded) do
      %{msg | content: [ContentPart.image(data, media_type)]}
    else
      _ -> msg
    end
  end

  defp expand_tool_image(msg), do: msg

  defp text_part(content) when is_list(content) do
    Enum.find_value(content, fn
      %ContentPart{type: :text, text: text} when is_binary(text) -> text
      _ -> nil
    end)
  end

  defp text_part(_content), do: nil

  defp decode_tool_image("get_tool_result", %{"screenshot" => _} = decoded) do
    Image.decode_tool_image_for_llm("take_screenshot", decoded)
  end

  defp decode_tool_image("get_tool_result", %{"type" => "image", "image" => _} = decoded) do
    Image.decode_tool_image_for_llm("web_fetch", decoded)
  end

  defp decode_tool_image(name, decoded), do: Image.decode_tool_image_for_llm(name, decoded)

  defp canonical_tool_name(name) when is_binary(name), do: String.replace_prefix(name, "mcp_", "")
  defp canonical_tool_name(name), do: name
end
