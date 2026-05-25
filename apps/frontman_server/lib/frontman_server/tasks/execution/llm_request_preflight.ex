# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.Tasks.Execution.LLMRequestPreflight do
  @moduledoc """
  LLM request preflight pipeline.

  Runs in `LLMClient` before each provider request. Each pass is a pure
  function over a list of `SwarmAi.Message` structs.

  Core principle: recent context is sacred, old context is compactable.
  A message is "old" if an assistant message appears after it — the model
  has already processed it.
  """

  use Boundary,
    deps: [FrontmanServer],
    check: [apps: [:req_llm]]

  require Logger

  alias FrontmanServer.CurrentPageContext
  alias FrontmanServer.Image
  alias SwarmAi.Message
  alias SwarmAi.Message.ContentPart

  @default_tool_result_max_bytes 51_200
  @old_image_placeholder "[image: previously analyzed]"
  @unsupported_image_placeholder "[Image omitted: selected model does not support image input]"

  @type opts :: keyword()

  @doc """
  Run the full request preflight pipeline over a list of messages.

  Returns the preflighted message list.
  """
  @spec run([Message.t()], opts()) :: [Message.t()]
  def run(messages, opts \\ []) do
    live_start_index = live_message_start_index(messages)

    messages
    |> compact_old_tool_results(live_start_index)
    |> expand_tool_result_images()
    |> decay_old_images(live_start_index)
    |> strip_unsupported_images(opts)
    |> constrain_image_dimensions(opts)
    |> truncate_tool_results(opts)
    |> dedup_page_context()
  end

  # Index after the last assistant message. Earlier messages have already been
  # processed by the model; later messages still belong to the live turn.
  @spec live_message_start_index([Message.t()]) :: non_neg_integer()
  defp live_message_start_index(messages) do
    messages
    |> Enum.with_index()
    |> Enum.reduce(0, fn {msg, idx}, acc ->
      if match?(%Message.Assistant{}, msg), do: idx + 1, else: acc
    end)
  end

  defp compact_old_tool_results(messages, _live_start_index), do: messages

  defp expand_tool_result_images(messages) do
    Enum.map(messages, &expand_tool_image/1)
  end

  defp expand_tool_image(%Message.Tool{name: name, content: content} = msg) do
    with json when is_binary(json) <- text_part(content),
         {:ok, decoded} when is_map(decoded) <- Jason.decode(json),
         {:ok, %{data: data, media_type: media_type}} <-
           decode_tool_image(canonical_tool_name(name), decoded) do
      %{msg | content: [ContentPart.image(data, media_type)]}
    else
      _ -> msg
    end
  end

  defp expand_tool_image(msg), do: msg

  defp text_part(content) when is_list(content) do
    Enum.find_value(content, fn
      %ContentPart{type: :text, text: text} when is_binary(text) -> text
      _ -> nil
    end)
  end

  defp text_part(_content), do: nil

  defp decode_tool_image("take_screenshot", %{"screenshot" => data_url})
       when is_binary(data_url),
       do: decode_tool_data_url(data_url)

  defp decode_tool_image("web_fetch", %{"image" => data_url})
       when is_binary(data_url),
       do: decode_tool_data_url(data_url)

  defp decode_tool_image("get_tool_result", %{"screenshot" => data_url})
       when is_binary(data_url),
       do: decode_tool_data_url(data_url)

  defp decode_tool_image("get_tool_result", %{"type" => "image", "image" => data_url})
       when is_binary(data_url),
       do: decode_tool_data_url(data_url)

  defp decode_tool_image(_name, _decoded), do: :no_image

  defp decode_tool_data_url(data_url) do
    case Image.decode_data_url(data_url) do
      {:ok, data, media_type} -> {:ok, %{data: data, media_type: media_type}}
      :error -> :no_image
    end
  end

  defp canonical_tool_name(name) when is_binary(name), do: String.replace_prefix(name, "mcp_", "")
  defp canonical_tool_name(name), do: name

  defp decay_old_images(messages, live_start_index) do
    messages
    |> Enum.with_index()
    |> Enum.map(&decay_old_image(&1, live_start_index))
  end

  defp decay_old_image({msg, idx}, live_start_index) when idx < live_start_index do
    decay_images(msg)
  end

  defp decay_old_image({msg, _idx}, _live_start_index), do: msg

  defp decay_images(%Message.Tool{} = msg), do: msg

  defp decay_images(%{content: content} = msg) when is_list(content) do
    new_content =
      Enum.map(content, fn
        %ContentPart{type: type} when type in [:image, :image_url] ->
          ContentPart.text(@old_image_placeholder)

        other ->
          other
      end)

    %{msg | content: new_content}
  end

  defp decay_images(msg), do: msg

  defp strip_unsupported_images(messages, opts) do
    case Keyword.get(opts, :images_supported, true) do
      false -> Enum.map(messages, &strip_message_images/1)
      _ -> messages
    end
  end

  defp strip_message_images(%{content: content} = message) when is_list(content) do
    %{message | content: Enum.map(content, &strip_image_part/1)}
  end

  defp strip_message_images(message), do: message

  defp strip_image_part(%ContentPart{type: type}) when type in [:image, :image_url] do
    ContentPart.text(@unsupported_image_placeholder)
  end

  defp strip_image_part(part), do: part

  defp constrain_image_dimensions(messages, opts) do
    case Keyword.get(opts, :max_image_dimension) do
      max when is_integer(max) -> Enum.map(messages, &constrain_message_images(&1, max))
      _ -> messages
    end
  end

  defp constrain_message_images(%{content: content} = message, max) when is_list(content) do
    %{message | content: Enum.map(content, &constrain_image_part(&1, max))}
  end

  defp constrain_message_images(message, _max), do: message

  defp constrain_image_part(%ContentPart{type: :image, data: data} = part, max) do
    case Image.check_dimensions(data, max) do
      :ok ->
        part

      {:too_large, width, height} ->
        Sentry.capture_message("Image exceeded provider dimension limit",
          level: :warning,
          extra: %{width: width, height: height, max_dimension: max}
        )

        Logger.warning("Stripping oversized image (#{width}x#{height}px, max #{max}px)")

        ContentPart.text(
          "[Image removed: dimensions #{width}x#{height}px exceed the #{max}px provider limit]"
        )
    end
  end

  defp constrain_image_part(part, _max), do: part

  defp truncate_tool_results(messages, opts) do
    max_bytes = tool_result_max_bytes(opts)

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
       when is_binary(text) do
    case byte_size(text) > max_bytes do
      true -> truncate_text_part(part, max_bytes, tool_call_id)
      false -> part
    end
  end

  defp maybe_truncate(part, _max_bytes, _tool_call_id), do: part

  defp truncate_text_part(%ContentPart{type: :text, text: text} = part, max_bytes, tool_call_id) do
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

  defp truncated_suffix(total, max_bytes, tool_call_id) when is_binary(tool_call_id) do
    "\n\n[Output truncated: #{total} bytes total, showing first #{max_bytes}. " <>
      "For the full output, use get_tool_result with tool_call_id #{tool_call_id}.]"
  end

  defp truncated_suffix(total, max_bytes, _tool_call_id) do
    "\n\n[Output truncated: #{total} bytes total, showing first #{max_bytes}.]"
  end

  defp tool_result_max_bytes(opts) do
    config =
      Application.get_env(:frontman_server, __MODULE__, [])
      |> Keyword.get(:tool_result_max_bytes, @default_tool_result_max_bytes)

    Keyword.get(opts, :tool_result_max_bytes, config)
  end

  defp dedup_page_context(messages) do
    {reversed, _prev} =
      Enum.reduce(messages, {[], nil}, fn msg, {acc, prev_context} ->
        case msg do
          %Message.User{} ->
            {new_msg, current_context} = dedup_context(msg, prev_context)
            {[new_msg | acc], current_context}

          _ ->
            {[msg | acc], prev_context}
        end
      end)

    Enum.reverse(reversed)
  end

  defp dedup_context(%Message.User{content: content} = msg, prev_context)
       when is_list(content) do
    {reversed_content, current_context} =
      Enum.reduce(content, {[], prev_context}, fn part, {parts, prev} ->
        dedup_context_part(extract_context(part), part, parts, prev)
      end)

    case Enum.reverse(reversed_content) do
      [] -> {msg, current_context}
      new_content -> {%{msg | content: new_content}, current_context}
    end
  end

  defp dedup_context(msg, prev_context), do: {msg, prev_context}

  defp dedup_context_part({stripped_part, context}, original_part, parts, prev_context) do
    case duplicate_context?(context, prev_context) do
      true -> {put_deduped_context_part(stripped_part, parts), context}
      false -> {[original_part | parts], context}
    end
  end

  defp dedup_context_part(nil, part, parts, prev_context) do
    {[part | parts], prev_context}
  end

  defp duplicate_context?(context, context), do: true
  defp duplicate_context?(_context, nil), do: false
  defp duplicate_context?(_context, _prev_context), do: false

  defp put_deduped_context_part(%ContentPart{type: :text, text: ""}, parts) do
    [ContentPart.text(CurrentPageContext.unchanged_placeholder()) | parts]
  end

  defp put_deduped_context_part(stripped_part, parts) do
    [stripped_part | parts]
  end

  defp extract_context(%ContentPart{type: :text, text: text}) when is_binary(text) do
    case CurrentPageContext.extract_prompt_section(text) do
      {stripped, context_block} -> {ContentPart.text(stripped), context_block}
      nil -> nil
    end
  end

  defp extract_context(_part), do: nil
end
