defmodule SwarmAi.LLM.Response do
  @moduledoc """
  Normalized response from an LLM call.

  Adapters convert provider-specific responses to this canonical format.
  Can be built from a ReqLLM stream via `from_stream/1`.
  """
  use TypedStruct

  require Logger

  alias ReqLLM.StreamChunk
  alias SwarmAi.LLM.Usage

  @type finish_reason ::
          :stop
          | :tool_calls
          | :length
          | :error
          | :content_filter
          | :cancelled
          | :incomplete
          | :unknown
          | nil

  typedstruct do
    field(:content, String.t())
    field(:reasoning_details, [map()], default: [])
    field(:finish_reason, finish_reason(), default: :stop)
    field(:tool_calls, [SwarmAi.ToolCall.t()], default: [])
    field(:usage, Usage.t())
    field(:metadata, map(), default: %{})
    field(:raw, term())
  end

  @doc "Returns `true` if the response contains any tool calls."
  @spec has_tool_calls?(t()) :: boolean()
  def has_tool_calls?(%__MODULE__{tool_calls: []}), do: false
  def has_tool_calls?(%__MODULE__{tool_calls: _}), do: true

  @doc """
  Build a Response from a stream of ReqLLM chunks.

  This is the batch-style convenience for when you don't need real-time
  token emission. Consumes the entire stream and returns the collected response.
  """
  @spec from_stream(Enumerable.t(StreamChunk.t())) :: t()
  def from_stream(stream) do
    chunks = if is_list(stream), do: stream, else: Enum.to_list(stream)
    summary = ReqLLM.Response.Stream.summarize(chunks)

    %__MODULE__{
      content: summary.text,
      reasoning_details: build_reasoning_details(chunks),
      tool_calls: summarize_tool_calls(chunks, summary.tool_calls),
      usage: build_usage(summary.usage),
      finish_reason: extract_finish_reason(chunks, summary.finish_reason),
      metadata: extract_response_metadata(chunks)
    }
  end

  defp summarize_tool_calls(chunks, summarized_tool_calls) do
    starts = extract_tool_call_starts(chunks)
    fragments_by_index = collect_tool_call_fragments(chunks)

    validate_tool_call_fragments!(starts, fragments_by_index)

    malformed_indexes = malformed_fragment_indexes(fragments_by_index)

    Enum.map(summarized_tool_calls, fn call ->
      id = fetch_tool_call_id!(call)
      args = tool_call_field(call, :arguments)
      fallback_name = tool_call_field(call, :name)

      case Map.get(starts, id) do
        nil ->
          %SwarmAi.ToolCall{
            id: id,
            name: fallback_name,
            arguments: encode_tool_call_arguments(args)
          }

        %{index: index, name: name, arguments: start_args} ->
          arguments =
            resolve_tool_call_arguments(
              id,
              name,
              index,
              args,
              start_args,
              fragments_by_index,
              malformed_indexes
            )

          %SwarmAi.ToolCall{id: id, name: name || fallback_name, arguments: arguments}
      end
    end)
  end

  defp extract_tool_call_starts(chunks) do
    Enum.reduce(chunks, %{}, fn
      %StreamChunk{type: :tool_call, name: name, arguments: arguments, metadata: metadata}, acc ->
        metadata = metadata || %{}

        case {meta_field(metadata, :id), normalize_index(meta_field(metadata, :index) || 0)} do
          {id, index} when is_binary(id) and is_integer(index) ->
            Map.put(acc, id, %{index: index, name: name, arguments: arguments})

          _other ->
            acc
        end

      _chunk, acc ->
        acc
    end)
  end

  defp collect_tool_call_fragments(chunks) do
    Enum.reduce(chunks, %{}, fn
      %StreamChunk{type: :meta, metadata: metadata}, acc ->
        case extract_tool_call_fragment(metadata || %{}) do
          {:ok, index, fragment} ->
            Map.update(acc, index, fragment, &(&1 <> fragment))

          :error ->
            acc
        end

      _chunk, acc ->
        acc
    end)
  end

  defp extract_tool_call_fragment(metadata) do
    case meta_field(metadata, :tool_call_args) do
      %{index: index, fragment: fragment} when is_binary(fragment) ->
        case normalize_index(index) do
          normalized when is_integer(normalized) -> {:ok, normalized, fragment}
          _other -> :error
        end

      %{"index" => index, "fragment" => fragment} when is_binary(fragment) ->
        case normalize_index(index) do
          normalized when is_integer(normalized) -> {:ok, normalized, fragment}
          _other -> :error
        end

      _other ->
        :error
    end
  end

  defp validate_tool_call_fragments!(starts, fragments_by_index) do
    start_indexes =
      starts
      |> Map.values()
      |> MapSet.new(& &1.index)

    Enum.each(Map.keys(fragments_by_index), fn index ->
      if not MapSet.member?(start_indexes, index) do
        raise ArgumentError,
              "Received tool_call_args for index #{index} but no tool_call_start was received. " <>
                "This indicates a bug in the streaming pipeline."
      end
    end)
  end

  defp malformed_fragment_indexes(fragments_by_index) do
    Enum.reduce(fragments_by_index, MapSet.new(), fn {index, fragment}, acc ->
      case Jason.decode(fragment) do
        {:ok, _decoded} -> acc
        {:error, _decode_error} -> MapSet.put(acc, index)
      end
    end)
  end

  defp resolve_tool_call_arguments(
         id,
         name,
         index,
         args,
         start_args,
         fragments_by_index,
         malformed_indexes
       ) do
    cond do
      MapSet.member?(malformed_indexes, index) ->
        raw = Map.fetch!(fragments_by_index, index)

        Logger.warning("Tool call #{name} (#{id}) has invalid JSON arguments: #{inspect(raw)}")

        raw

      not Map.has_key?(fragments_by_index, index) and empty_tool_call_arguments?(start_args) ->
        Logger.warning(
          "Tool call #{name} (#{id}) missing streamed argument fragments; defaulting arguments to {}"
        )

        "{}"

      true ->
        encode_tool_call_arguments(args)
    end
  end

  defp fetch_tool_call_id!(call) when is_map(call) do
    case tool_call_field(call, :id) do
      id when is_binary(id) -> id
      _other -> raise KeyError, key: :id, term: call
    end
  end

  defp tool_call_field(call, key) when is_map(call) and is_atom(key) do
    Map.get(call, key) || Map.get(call, Atom.to_string(key))
  end

  defp encode_tool_call_arguments(nil), do: "{}"
  defp encode_tool_call_arguments(args) when is_binary(args), do: args
  defp encode_tool_call_arguments(args) when is_map(args), do: Jason.encode!(args)
  defp encode_tool_call_arguments(args), do: Jason.encode!(args)

  defp empty_tool_call_arguments?(nil), do: true

  defp empty_tool_call_arguments?(args) when is_binary(args) do
    String.trim(args) in ["", "{}"]
  end

  defp empty_tool_call_arguments?(args) when is_map(args), do: map_size(args) == 0
  defp empty_tool_call_arguments?(_), do: false

  defp build_reasoning_details(chunks) do
    {entries, _index} =
      Enum.reduce(chunks, {[], 0}, fn
        %StreamChunk{type: :thinking, text: text, metadata: metadata}, {acc, index}
        when is_binary(text) ->
          entry = build_reasoning_entry(text, metadata || %{}, index)
          {[entry | acc], index + 1}

        _chunk, state ->
          state
      end)

    Enum.reverse(entries)
  end

  defp build_reasoning_entry(text, metadata, index) do
    metadata
    |> Map.put("text", text)
    |> Map.put("index", index)
  end

  defp build_usage(nil), do: nil
  defp build_usage(usage) when is_map(usage), do: Usage.from_map(usage)
  defp build_usage(_other), do: nil

  defp extract_finish_reason(chunks, fallback_finish_reason) do
    finish_reason =
      Enum.reduce(chunks, nil, fn
        %StreamChunk{type: :meta, metadata: metadata}, acc ->
          case normalize_finish_reason(meta_field(metadata || %{}, :finish_reason)) do
            nil -> acc
            reason -> merge_finish_reason(acc, reason)
          end

        _chunk, acc ->
          acc
      end)

    finish_reason || fallback_finish_reason || :stop
  end

  defp merge_finish_reason(current, reason) when current in [nil, :stop], do: reason
  defp merge_finish_reason(current, _reason), do: current

  defp extract_response_metadata(chunks) do
    Enum.reduce(chunks, %{}, fn
      %StreamChunk{type: :meta, metadata: metadata}, acc ->
        acc
        |> maybe_put_response_id(metadata || %{})
        |> maybe_put_phase(metadata || %{})
        |> maybe_put_phase_items(metadata || %{})

      _chunk, acc ->
        acc
    end)
  end

  defp maybe_put_response_id(metadata, source) do
    case meta_field(source, :response_id) do
      id when is_binary(id) -> Map.put(metadata, :response_id, id)
      _other -> metadata
    end
  end

  defp maybe_put_phase(metadata, source) do
    case meta_field(source, :phase) do
      phase when is_binary(phase) -> Map.put(metadata, :phase, phase)
      _other -> metadata
    end
  end

  defp maybe_put_phase_items(metadata, source) do
    case meta_field(source, :phase_items) do
      phase_items when is_list(phase_items) and phase_items != [] ->
        Map.put(metadata, :phase_items, phase_items)

      _other ->
        metadata
    end
  end

  defp meta_field(map, key) when is_map(map) and is_atom(key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp normalize_index(index) when is_integer(index), do: index

  defp normalize_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {value, ""} -> value
      _other -> :error
    end
  end

  defp normalize_index(_other), do: :error

  defp normalize_finish_reason(nil), do: nil
  defp normalize_finish_reason(reason) when is_atom(reason), do: reason
  defp normalize_finish_reason("stop"), do: :stop
  defp normalize_finish_reason("completed"), do: :stop
  defp normalize_finish_reason("tool_calls"), do: :tool_calls
  defp normalize_finish_reason("length"), do: :length
  defp normalize_finish_reason("max_tokens"), do: :length
  defp normalize_finish_reason("max_output_tokens"), do: :length
  defp normalize_finish_reason("content_filter"), do: :content_filter
  defp normalize_finish_reason("tool_use"), do: :tool_calls
  defp normalize_finish_reason("end_turn"), do: :stop
  defp normalize_finish_reason("error"), do: :error
  defp normalize_finish_reason("cancelled"), do: :cancelled
  defp normalize_finish_reason("incomplete"), do: :incomplete
  defp normalize_finish_reason(_other), do: :unknown
end
