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
    result = Enum.reduce(stream, initial_stream_state(), &accumulate_chunk/2)

    %__MODULE__{
      content: IO.iodata_to_binary(result.content),
      reasoning_details: Enum.reverse(result.reasoning_details),
      tool_calls: finalize_tool_calls(result.tool_calls_by_id, result.fragments_by_index),
      usage: build_usage(result.usage),
      finish_reason: result.finish_reason || :stop,
      metadata: result.metadata
    }
  end

  defp initial_stream_state do
    %{
      content: [],
      reasoning_details: [],
      reasoning_index: 0,
      tool_calls_by_id: %{},
      tool_call_indexes: MapSet.new(),
      fragments_by_index: %{},
      usage: nil,
      finish_reason: nil,
      metadata: %{}
    }
  end

  defp accumulate_chunk(%StreamChunk{type: :content, text: text}, acc) when is_binary(text) do
    %{acc | content: [acc.content, text]}
  end

  defp accumulate_chunk(
         %StreamChunk{type: :thinking, text: text, metadata: metadata},
         acc
       )
       when is_binary(text) do
    entry = build_reasoning_entry(text, metadata || %{}, acc.reasoning_index)

    %{
      acc
      | reasoning_details: [entry | acc.reasoning_details],
        reasoning_index: acc.reasoning_index + 1
    }
  end

  defp accumulate_chunk(
         %StreamChunk{type: :tool_call, name: name, arguments: arguments, metadata: metadata},
         acc
       ) do
    metadata = metadata || %{}

    case {meta_field(metadata, :id), normalize_index(meta_field(metadata, :index) || 0)} do
      {id, index} when is_binary(id) and is_integer(index) ->
        call = %{id: id, name: name, arguments: arguments, index: index}

        %{
          acc
          | tool_calls_by_id: Map.put(acc.tool_calls_by_id, id, call),
            tool_call_indexes: MapSet.put(acc.tool_call_indexes, index)
        }

      _other ->
        acc
    end
  end

  defp accumulate_chunk(%StreamChunk{type: :meta, metadata: metadata}, acc) do
    metadata = metadata || %{}

    acc
    |> accumulate_tool_call_fragment(metadata)
    |> maybe_put_usage(metadata)
    |> maybe_put_finish_reason(metadata)
    |> maybe_put_response_metadata(metadata)
  end

  defp accumulate_chunk(_chunk, acc), do: acc

  defp accumulate_tool_call_fragment(acc, metadata) do
    case extract_tool_call_fragment(metadata) do
      {:ok, index, fragment} ->
        if not MapSet.member?(acc.tool_call_indexes, index) do
          raise ArgumentError,
                "Received tool_call_args for index #{index} but no tool_call_start was received. " <>
                  "This indicates a bug in the streaming pipeline."
        end

        %{
          acc
          | fragments_by_index:
              Map.update(acc.fragments_by_index, index, fragment, &(&1 <> fragment))
        }

      :error ->
        acc
    end
  end

  defp finalize_tool_calls(tool_calls_by_id, fragments_by_index) do
    malformed_indexes = malformed_fragment_indexes(fragments_by_index)

    tool_calls_by_id
    |> Map.values()
    |> Enum.sort_by(& &1.index)
    |> Enum.map(fn %{id: id, index: index, name: name, arguments: start_arguments} ->
      arguments =
        resolve_tool_call_arguments(
          id,
          name,
          index,
          start_arguments,
          fragments_by_index,
          malformed_indexes
        )

      %SwarmAi.ToolCall{id: id, name: name, arguments: arguments}
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
         start_arguments,
         fragments_by_index,
         malformed_indexes
       ) do
    cond do
      MapSet.member?(malformed_indexes, index) ->
        raw = Map.fetch!(fragments_by_index, index)

        Logger.warning("Tool call #{name} (#{id}) has invalid JSON arguments: #{inspect(raw)}")

        raw

      Map.has_key?(fragments_by_index, index) ->
        Map.fetch!(fragments_by_index, index)

      empty_tool_call_arguments?(start_arguments) ->
        Logger.warning(
          "Tool call #{name} (#{id}) missing streamed argument fragments; preserving empty arguments"
        )

        ""

      true ->
        encode_tool_call_arguments(start_arguments)
    end
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

  defp build_reasoning_entry(text, metadata, index) do
    metadata
    |> Map.put("text", text)
    |> Map.put("index", index)
  end

  defp build_usage(nil), do: nil
  defp build_usage(usage) when is_map(usage), do: Usage.from_map(usage)
  defp build_usage(_other), do: nil

  defp maybe_put_usage(acc, metadata) do
    case meta_field(metadata, :usage) do
      usage when is_map(usage) -> %{acc | usage: usage}
      _other -> acc
    end
  end

  defp maybe_put_finish_reason(acc, metadata) do
    case normalize_finish_reason(meta_field(metadata, :finish_reason)) do
      nil -> acc
      reason -> %{acc | finish_reason: merge_finish_reason(acc.finish_reason, reason)}
    end
  end

  defp merge_finish_reason(current, reason) when current in [nil, :stop], do: reason
  defp merge_finish_reason(current, _reason), do: current

  defp maybe_put_response_metadata(acc, metadata) do
    %{
      acc
      | metadata:
          acc.metadata
          |> maybe_put_response_id(metadata)
          |> maybe_put_phase(metadata)
          |> maybe_put_phase_items(metadata)
    }
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

  defp normalize_finish_reason(reason) when is_atom(reason),
    do: normalize_finish_reason(Atom.to_string(reason))

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
