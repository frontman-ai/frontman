# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule AgentClientProtocol.Content do
  @moduledoc "Builders for ACP content blocks."

  defmodule TextBlock do
    @moduledoc false
    @enforce_keys [:text]
    defstruct [:text]

    defimpl Jason.Encoder do
      def encode(%{text: text}, opts) do
        Jason.Encode.map(%{"type" => "text", "text" => text}, opts)
      end
    end
  end

  defmodule ContentItem do
    @moduledoc false
    @enforce_keys [:content]
    defstruct [:content]

    defimpl Jason.Encoder do
      def encode(%{content: block}, opts) do
        Jason.Encode.map(%{"type" => "content", "content" => block}, opts)
      end
    end
  end

  def text(text) when is_binary(text), do: %TextBlock{text: text}

  def wrap(%TextBlock{} = block), do: %ContentItem{content: block}

  def from_tool_result(%{"content" => content}) when is_list(content) do
    Enum.map(content, fn
      %{"type" => "text", "text" => text} when is_binary(text) ->
        text |> text() |> wrap()

      part ->
        part |> Jason.encode!() |> text() |> wrap()
    end)
  end

  def from_tool_result(result) when is_map(result),
    do: [result |> Jason.encode!() |> text() |> wrap()]

  def from_tool_result(result) when is_binary(result), do: [result |> text() |> wrap()]
  def from_tool_result(result), do: [result |> inspect() |> text() |> wrap()]
end
