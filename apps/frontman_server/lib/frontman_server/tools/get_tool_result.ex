# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tools.GetToolResult do
  @moduledoc """
  Retrieves a persisted tool result by tool call ID.
  """

  @behaviour FrontmanServer.Tools.Backend

  alias FrontmanServer.Tasks.Interaction.ToolResult
  alias FrontmanServer.Tasks.InteractionSchema
  alias FrontmanServer.Tools.Backend.Context
  alias ModelContextProtocol, as: MCP

  @impl true
  def name, do: "get_tool_result"

  @impl true
  def description do
    """
    Retrieve a previous tool result by tool_call_id.

    Use this when a prior tool result says its data was omitted. Pass the exact
    tool_call_id from that placeholder to retrieve the original ToolResult.
    For truncated text, pass offset=0 and content_index=0, then follow next_offset
    until null. Offsets and limits are UTF-8 bytes; use returned offsets verbatim.
    Paged responses preserve the source error flag and list the content part count.
    """
  end

  @impl true
  def access, do: :read

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "tool_call_id" => %{
          "type" => "string",
          "description" => "The tool_call_id for the tool result to retrieve."
        },
        "offset" => %{"type" => "integer", "minimum" => 0},
        "limit" => %{"type" => "integer", "minimum" => 4, "maximum" => 8000},
        "content_index" => %{"type" => "integer", "minimum" => 0}
      },
      "required" => ["tool_call_id"]
    }
  end

  @impl true
  def timeout_ms, do: 30_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, %Context{task: %{interaction_rows: rows}}) do
    case Map.get(args, "tool_call_id") do
      tool_call_id when is_binary(tool_call_id) ->
        result = find_tool_result(rows, tool_call_id)

        case Enum.any?(["offset", "limit", "content_index"], &Map.has_key?(args, &1)) do
          true -> page_result(result, args)
          false -> result
        end

      _ ->
        MCP.tool_result_error("tool_call_id must be a string")
    end
  end

  defp page_result(%{"content" => content} = result, args) do
    offset = Map.get(args, "offset", 0)
    limit = Map.get(args, "limit", 8000)
    index = Map.get(args, "content_index", 0)

    with true <- is_integer(offset),
         true <- offset >= 0,
         true <- is_integer(limit),
         true <- limit in 4..8000,
         true <- is_integer(index),
         true <- index >= 0,
         %{"type" => "text", "text" => text} when is_binary(text) <- Enum.at(content, index),
         true <- offset <= byte_size(text) do
      length = min(limit, byte_size(text) - offset)

      case :unicode.characters_to_binary(binary_part(text, offset, length), :utf8, :utf8) do
        chunk when is_binary(chunk) ->
          text_page(result, chunk, text, offset, index)

        {:incomplete, chunk, _rest} ->
          text_page(result, chunk, text, offset, index)

        {:error, _chunk, _rest} ->
          MCP.tool_result_error("offset must be a UTF-8 character boundary")
      end
    else
      _ ->
        MCP.tool_result_error(
          "Paging requires a text content_index, offset within the text, and limit between 4 and 8000 bytes"
        )
    end
  end

  defp text_page(result, chunk, text, offset, index) do
    next = offset + byte_size(chunk)

    next_offset =
      case next < byte_size(text) do
        true -> next
        false -> nil
      end

    payload =
      Jason.encode!(%{
        text: chunk,
        content_index: index,
        content_count: length(result["content"]),
        total_bytes: byte_size(text),
        offset: offset,
        next_offset: next_offset
      })

    result
    |> Map.take(["isError"])
    |> Map.put("content", [%{"type" => "text", "text" => payload}])
  end

  defp find_tool_result(rows, tool_call_id) do
    case Enum.find(rows, fn
           %InteractionSchema{data: %ToolResult{tool_call_id: ^tool_call_id}} -> true
           _row -> false
         end) do
      nil ->
        MCP.tool_result_error("Tool result not found: #{tool_call_id}")

      %InteractionSchema{data: %ToolResult{result: %{"content" => content} = result}}
      when is_list(content) ->
        if Enum.all?(content, &is_map/1) do
          result
        else
          MCP.tool_result_error("Stored tool result is invalid: content must be list of objects")
        end

      %InteractionSchema{data: %ToolResult{}} ->
        MCP.tool_result_error(
          "Stored tool result for #{tool_call_id} is not a valid MCP tool result"
        )
    end
  end
end
