# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 - see LICENSE for details.
# Additional terms apply - see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Protocols.MCP.ToolOutput do
  @moduledoc """
  Validated complete tool output. Structured JSON null is distinct from absence.

  Persisted historical results omit the discriminator and are treated as complete.
  Explicit interim results never become tool output.
  """

  alias FrontmanServer.Protocols.MCP.Schema

  @enforce_keys [:content, :structured_content, :is_error]
  defstruct [:content, :structured_content, :is_error]

  @opaque t :: %__MODULE__{
            content: [map()],
            structured_content: :absent | {:present, Jason.Encoder.t()},
            is_error: boolean()
          }

  @spec new(map(), map() | nil) :: {:ok, t()} | :error
  def new(result, output_schema \\ nil) when is_map(result) do
    result = Map.put_new(result, "resultType", "complete")

    with %{"resultType" => "complete"} <- result,
         :ok <- Schema.validate_call_tool_result(result, output_schema) do
      {:ok,
       %__MODULE__{
         content: Map.fetch!(result, "content"),
         structured_content: structured_content(result),
         is_error: Map.get(result, "isError", false)
       }}
    else
      _invalid -> :error
    end
  end

  @doc """
  Keeps original blocks in order and appends structured JSON unless a text block
  already parses to the same JSON value. Prose is never treated as equivalent.
  """
  def content_blocks(%__MODULE__{content: content, structured_content: :absent}),
    do: content

  def content_blocks(%__MODULE__{content: content, structured_content: {:present, value}}) do
    case Enum.any?(content, &equivalent_json_text?(&1, value)) do
      true -> content
      false -> content ++ [%{"type" => "text", "text" => Jason.encode!(value)}]
    end
  end

  defp structured_content(result) do
    case Map.fetch(result, "structuredContent") do
      {:ok, value} -> {:present, value}
      :error -> :absent
    end
  end

  defp equivalent_json_text?(%{"type" => "text", "text" => text}, value) do
    case Jason.decode(text) do
      {:ok, decoded} -> decoded == value
      {:error, _error} -> false
    end
  end

  defp equivalent_json_text?(_block, _value), do: false
end
