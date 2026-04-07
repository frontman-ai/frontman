defmodule FrontmanServer.Tasks.MessageOptimizer.ToolResultTruncation do
  @moduledoc """
  Caps tool result text content at a maximum byte size before sending to the LLM.

  Applies to all tool results (old and live). The full content is preserved in the
  DB — only the LLM message is capped.

  Matches opencode's 50KB limit by default.
  """

  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  @default_max_bytes 51_200

  @spec run([Message.t()], keyword()) :: [Message.t()]
  def run(messages, opts \\ []) do
    max_bytes = max_bytes(opts)

    Enum.map(messages, fn msg ->
      if msg.role == :tool, do: truncate_tool_result(msg, max_bytes), else: msg
    end)
  end

  defp truncate_tool_result(%Message{content: content} = msg, max_bytes)
       when is_list(content) do
    %{msg | content: Enum.map(content, &maybe_truncate(&1, max_bytes))}
  end

  defp truncate_tool_result(msg, _max_bytes), do: msg

  defp maybe_truncate(%ContentPart{type: :text, text: text} = part, max_bytes)
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

    suffix =
      "\n\n[Output truncated: #{total} bytes total, showing first #{max_bytes}. " <>
        "Use search or read tools with line offsets to retrieve specific sections.]"

    %{part | text: trimmed <> suffix}
  end

  defp maybe_truncate(part, _max_bytes), do: part

  defp max_bytes(opts) do
    config =
      Application.get_env(:frontman_server, FrontmanServer.Tasks.MessageOptimizer, [])
      |> Keyword.get(:tool_result_max_bytes, @default_max_bytes)

    Keyword.get(opts, :tool_result_max_bytes, config)
  end
end
