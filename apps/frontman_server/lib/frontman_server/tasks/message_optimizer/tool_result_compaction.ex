defmodule FrontmanServer.Tasks.MessageOptimizer.ToolResultCompaction do
  @moduledoc """
  Strip metadata keys from old tool result JSON that served a one-time
  purpose (pagination info the model already acted on).

  Live tool results are untouched.
  """

  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  @default_strip_keys ["start_line", "lines_returned", "total_lines"]

  @spec run([Message.t()], non_neg_integer(), keyword()) :: [Message.t()]
  def run(messages, old_boundary, opts \\ []) do
    strip_keys = strip_keys(opts)

    messages
    |> Enum.with_index()
    |> Enum.map(fn {msg, idx} ->
      if idx < old_boundary and msg.role == :tool do
        compact_tool_result(msg, strip_keys)
      else
        msg
      end
    end)
  end

  defp compact_tool_result(%Message{content: content} = msg, strip_keys)
       when is_list(content) do
    new_content = Enum.map(content, &maybe_strip_json_keys(&1, strip_keys))
    %{msg | content: new_content}
  end

  defp compact_tool_result(msg, _strip_keys), do: msg

  defp maybe_strip_json_keys(%ContentPart{type: :text, text: text} = part, strip_keys)
       when is_binary(text) do
    case Jason.decode(text) do
      {:ok, decoded} when is_map(decoded) ->
        stripped = Map.drop(decoded, strip_keys)

        case Jason.encode(stripped) do
          {:ok, json} -> %{part | text: json}
          _ -> part
        end

      _ ->
        part
    end
  end

  defp maybe_strip_json_keys(part, _strip_keys), do: part

  defp strip_keys(opts) do
    config_keys =
      Application.get_env(:frontman_server, FrontmanServer.Tasks.MessageOptimizer, [])
      |> Keyword.get(:tool_result_strip_keys, @default_strip_keys)

    Keyword.get(opts, :tool_result_strip_keys, config_keys)
  end
end
