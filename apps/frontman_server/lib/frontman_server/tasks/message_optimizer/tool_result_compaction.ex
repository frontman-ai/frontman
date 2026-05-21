# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.MessageOptimizer.ToolResultCompaction do
  @moduledoc """
  Replace old non-image tool results with a recoverable placeholder.

  Live tool results are untouched.
  """

  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  @image_tool_names MapSet.new(["take_screenshot", "web_fetch"])

  @spec run([Message.t()], non_neg_integer(), keyword()) :: [Message.t()]
  def run(messages, old_boundary, _opts \\ []) do
    messages
    |> Enum.with_index()
    |> Enum.map(fn {msg, idx} ->
      if idx < old_boundary and msg.role == :tool do
        compact_tool_result(msg)
      else
        msg
      end
    end)
  end

  defp compact_tool_result(%Message{tool_call_id: id} = msg) when is_binary(id) do
    if image_tool_name?(msg.name),
      do: msg,
      else: %{msg | content: [ContentPart.text(placeholder(id))]}
  end

  defp compact_tool_result(msg), do: msg

  defp placeholder(id), do: "[Omitted data. For the data, use get_interaction for #{id}.]"

  defp image_tool_name?(name) when is_binary(name) do
    name
    |> String.replace_prefix("mcp_", "")
    |> then(&MapSet.member?(@image_tool_names, &1))
  end

  defp image_tool_name?(_), do: false
end
