# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.MessageOptimizer.ConstrainImageDimensions do
  @moduledoc """
  Replaces image content parts that exceed provider hard dimension limits.
  """

  require Logger

  alias FrontmanServer.{Image, Providers}
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  @spec run([Message.t()], keyword()) :: [Message.t()]
  def run(messages, opts \\ []) do
    case Keyword.get(opts, :provider) do
      provider when is_binary(provider) -> constrain_for_provider(messages, provider)
      _ -> messages
    end
  end

  defp constrain_for_provider(messages, provider) do
    case Providers.max_image_dimension(provider) do
      nil -> messages
      max -> Enum.map(messages, &constrain_message_images(&1, max))
    end
  end

  defp constrain_message_images(%{content: content} = message, max) when is_list(content) do
    %{message | content: Enum.map(content, &constrain_image_part(&1, max))}
  end

  defp constrain_message_images(message, _max), do: message

  defp constrain_image_part(%ContentPart{type: :image, data: data} = part, max) do
    case Image.check_dimensions(data, max) do
      :ok ->
        part

      {:too_large, width, height} ->
        Sentry.capture_message("Image exceeded provider dimension limit",
          level: :warning,
          extra: %{width: width, height: height, max_dimension: max}
        )

        Logger.warning("Stripping oversized image (#{width}x#{height}px, max #{max}px)")

        ContentPart.text(
          "[Image removed: dimensions #{width}x#{height}px exceed the #{max}px provider limit]"
        )
    end
  end

  defp constrain_image_part(part, _max), do: part
end
