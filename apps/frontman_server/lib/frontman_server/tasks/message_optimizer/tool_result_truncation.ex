# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.MessageOptimizer.ToolResultTruncation do
  @moduledoc """
  Caps tool result text content at a maximum byte size before sending to the LLM.

  Applies to all tool results (old and live). The full content is preserved in the
  DB — only the LLM message is capped.

  Matches opencode's 50KB limit by default.
  """

  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  @default_max_bytes 51_200

  @spec run([Message.t()], keyword()) :: [Message.t()]
  def run(messages, opts \\ []) do
    max_bytes = max_bytes(opts)

    Enum.map(messages, fn
      %Message.Tool{} = msg -> truncate_tool_result(msg, max_bytes)
      msg -> msg
    end)
  end

  defp truncate_tool_result(%Message.Tool{content: content} = msg, max_bytes)
       when is_list(content) do
    %{msg | content: Enum.map(content, &maybe_truncate(&1, max_bytes, msg.tool_call_id))}
  end

  defp truncate_tool_result(msg, _max_bytes), do: msg

  defp maybe_truncate(%ContentPart{type: :text, text: text} = part, max_bytes, tool_call_id)
       when is_binary(text) and byte_size(text) > max_bytes do
    # binary_part/3 is byte-level and can split a multi-byte UTF-8 sequence.
    # :unicode.characters_to_binary/3 recovers the longest valid prefix.
    trimmed =
      case :unicode.characters_to_binary(binary_part(text, 0, max_bytes), :utf8, :utf8) do
        result when is_binary(result) -> result
        {:incomplete, valid, _rest} -> valid
        {:error, valid, _rest} -> valid
      end

    total = byte_size(text)

    suffix = truncated_suffix(total, max_bytes, tool_call_id)

    %{part | text: trimmed <> suffix}
  end

  defp maybe_truncate(part, _max_bytes, _tool_call_id), do: part

  defp truncated_suffix(total, max_bytes, tool_call_id) when is_binary(tool_call_id) do
    "\n\n[Output truncated: #{total} bytes total, showing first #{max_bytes}. " <>
      "For the full output, use get_tool_result with tool_call_id #{tool_call_id}.]"
  end

  defp truncated_suffix(total, max_bytes, _tool_call_id) do
    "\n\n[Output truncated: #{total} bytes total, showing first #{max_bytes}.]"
  end

  defp max_bytes(opts) do
    config =
      Application.get_env(:frontman_server, FrontmanServer.Tasks.MessageOptimizer, [])
      |> Keyword.get(:tool_result_max_bytes, @default_max_bytes)

    Keyword.get(opts, :tool_result_max_bytes, config)
  end
end
