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
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "tool_call_id" => %{
          "type" => "string",
          "description" => "The tool_call_id for the tool result to retrieve."
        }
      },
      "required" => ["tool_call_id"]
    }
  end

  @impl true
  def timeout_ms, do: 30_000

  @impl true
  def on_timeout, do: :error

  @impl true
  def execute(args, %Context{task: %{interactions: interactions}}) do
    case Map.get(args, "tool_call_id") do
      tool_call_id when is_binary(tool_call_id) ->
        find_tool_result(interactions, tool_call_id)

      _ ->
        MCP.tool_result_error("tool_call_id must be a string")
    end
  end

  defp find_tool_result(interactions, tool_call_id) do
    case Enum.find(interactions, &match?(%ToolResult{tool_call_id: ^tool_call_id}, &1)) do
      nil ->
        MCP.tool_result_error("Tool result not found: #{tool_call_id}")

      %ToolResult{result: %{"content" => content} = result} when is_list(content) ->
        if Enum.all?(content, &is_map/1) do
          result
        else
          MCP.tool_result_error("Stored tool result is invalid: content must be list of objects")
        end

      %ToolResult{} ->
        MCP.tool_result_error(
          "Stored tool result for #{tool_call_id} is not a valid MCP tool result"
        )
    end
  end
end
