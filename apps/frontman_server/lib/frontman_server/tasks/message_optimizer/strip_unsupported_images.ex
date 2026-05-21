# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.MessageOptimizer.StripUnsupportedImages do
  @moduledoc """
  Replaces image content parts when the selected model cannot accept images.
  """

  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  @placeholder "[Image omitted: selected model does not support image input]"

  @spec run([Message.t()], keyword()) :: [Message.t()]
  def run(messages, opts \\ []) do
    case Keyword.fetch(opts, :model) do
      {:ok, model} -> strip_images_unless_supported(messages, model)
      :error -> messages
    end
  end

  defp strip_images_unless_supported(messages, model) do
    case ReqLLM.model(model) do
      {:ok, %{modalities: %{input: input}}} when is_list(input) ->
        case image_supported?(input) do
          true -> messages
          false -> Enum.map(messages, &strip_message_images/1)
        end

      _ ->
        messages
    end
  end

  defp image_supported?(input), do: :image in input

  defp strip_message_images(%{content: content} = message) when is_list(content) do
    %{message | content: Enum.map(content, &strip_image_part/1)}
  end

  defp strip_message_images(message), do: message

  defp strip_image_part(%ContentPart{type: type}) when type in [:image, :image_url] do
    ContentPart.text(@placeholder)
  end

  defp strip_image_part(part), do: part
end
