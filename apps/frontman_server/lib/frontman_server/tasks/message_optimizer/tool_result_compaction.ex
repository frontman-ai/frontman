# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.MessageOptimizer.ToolResultCompaction do
  @moduledoc """
  Replace old tool results with a recoverable placeholder.

  Live tool results are untouched.
  """

  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  @spec run([Message.t()], non_neg_integer(), keyword()) :: [Message.t()]
  def run(messages, old_boundary, _opts \\ []) do
    messages
    |> Enum.with_index()
    |> Enum.map(fn {msg, idx} ->
      if idx < old_boundary and match?(%Message.Tool{}, msg) do
        compact_tool_result(msg)
      else
        msg
      end
    end)
  end

  defp compact_tool_result(%Message.Tool{tool_call_id: id} = msg) when is_binary(id) do
    %{msg | content: [ContentPart.text(placeholder(id))]}
  end

  defp compact_tool_result(msg), do: msg

  defp placeholder(id) do
    "[Omitted data. For the data, use get_tool_result with tool_call_id #{id}.]"
  end
end
