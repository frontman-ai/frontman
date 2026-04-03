defmodule FrontmanServer.Tasks.MessageOptimizer.PageContextDedup do
  @moduledoc """
  Strip duplicate `[Current Page Context]` blocks from user messages.

  The page context block (URL, viewport, DPR, title, color scheme, scroll)
  is appended to every user message. When consecutive user messages share
  the same context, duplicates are replaced with a short reference.
  The first occurrence is always kept.
  """

  alias ReqLLM.Message
  alias ReqLLM.Message.ContentPart

  @context_pattern ~r/\n\[Current Page Context\]\n.+\z/s

  @spec run([Message.t()], keyword()) :: [Message.t()]
  def run(messages, _opts \\ []) do
    {reversed, _prev} =
      Enum.reduce(messages, {[], nil}, fn msg, {acc, prev_context} ->
        if msg.role == :user do
          {new_msg, current_context} = dedup_context(msg, prev_context)
          {[new_msg | acc], current_context}
        else
          {[msg | acc], prev_context}
        end
      end)

    Enum.reverse(reversed)
  end

  defp dedup_context(%Message{content: content} = msg, prev_context)
       when is_list(content) do
    {reversed_content, current_context} =
      Enum.reduce(content, {[], prev_context}, fn part, {parts, prev} ->
        case extract_context(part) do
          {%ContentPart{type: :text, text: ""}, context}
          when context == prev and not is_nil(prev) ->
            {parts, context}

          {stripped_part, context} when context == prev and not is_nil(prev) ->
            {[stripped_part | parts], context}

          {_stripped_part, context} ->
            {[part | parts], context}

          nil ->
            {[part | parts], prev}
        end
      end)

    case Enum.reverse(reversed_content) do
      [] -> {msg, current_context}
      new_content -> {%{msg | content: new_content}, current_context}
    end
  end

  defp dedup_context(msg, prev_context), do: {msg, prev_context}

  defp extract_context(%ContentPart{type: :text, text: text}) when is_binary(text) do
    case Regex.run(@context_pattern, text) do
      [context_block] ->
        stripped = String.replace(text, @context_pattern, "")
        stripped_part = ContentPart.text(stripped)
        {stripped_part, context_block}

      nil ->
        nil
    end
  end

  defp extract_context(_part), do: nil
end
