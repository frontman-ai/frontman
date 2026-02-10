defmodule Swarm.LLM.Response do
  @moduledoc """
  Normalized response from an LLM call.

  Adapters convert provider-specific responses to this canonical format.
  Can be built from a stream via `from_stream/1`.
  """
  use TypedStruct

  require Logger

  alias Swarm.LLM.{Chunk, Usage}

  @type finish_reason :: :stop | :tool_calls | :length | :error | nil

  typedstruct do
    field(:content, String.t())
    field(:reasoning_details, [map()], default: [])
    field(:finish_reason, finish_reason(), default: :stop)
    field(:tool_calls, [Swarm.ToolCall.t()], default: [])
    field(:usage, Usage.t())
    field(:metadata, map(), default: %{})
    field(:raw, term())
  end

  @spec has_tool_calls?(t()) :: boolean()
  def has_tool_calls?(%__MODULE__{tool_calls: []}), do: false
  def has_tool_calls?(%__MODULE__{tool_calls: _}), do: true

  @doc """
  Build a Response from a stream of chunks.

  This is the batch-style convenience for when you don't need real-time
  token emission. Consumes the entire stream and returns the collected response.

  Handles streaming tool calls by accumulating argument fragments:
  - `:tool_call_start` - begins tracking a new tool call
  - `:tool_call_args` - accumulates argument JSON fragments
  - `:tool_call_end` - complete tool call (non-streaming case)
  """
  @spec from_stream(Enumerable.t(Chunk.t())) :: t()
  def from_stream(stream) do
    acc = %{
      content: [],
      reasoning_details: [],
      # Complete tool calls (from :tool_call_end chunks)
      tool_calls: %{},
      # Pending tool calls being accumulated (from streaming)
      # Key: index, Value: %{id: string, name: string, args_fragments: [string]}
      pending_tool_calls: %{},
      usage: nil,
      finish_reason: :stop,
      metadata: %{}
    }

    result = Enum.reduce(stream, acc, &accumulate_chunk/2)

    # Finalize any pending streaming tool calls
    finalized_pending = finalize_pending_tool_calls(result.pending_tool_calls)

    # Merge complete tool calls with finalized pending ones
    all_tool_calls = Map.merge(result.tool_calls, finalized_pending)

    %__MODULE__{
      content: IO.iodata_to_binary(result.content),
      reasoning_details: result.reasoning_details,
      tool_calls: Map.values(all_tool_calls),
      usage: result.usage,
      finish_reason: result.finish_reason,
      metadata: result.metadata
    }
  end

  defp accumulate_chunk(%Chunk{type: :token, text: text}, acc) do
    %{acc | content: [acc.content, text]}
  end

  defp accumulate_chunk(%Chunk{type: :thinking, text: text, metadata: meta}, acc) do
    entry = build_reasoning_entry(text, meta, length(acc.reasoning_details))
    %{acc | reasoning_details: acc.reasoning_details ++ [entry]}
  end

  # Streaming: tool call name received, start accumulating
  defp accumulate_chunk(
         %Chunk{
           type: :tool_call_start,
           tool_call_id: id,
           tool_call_name: name,
           tool_call_index: index
         },
         acc
       ) do
    pending = %{id: id, name: name, args_fragments: []}
    %{acc | pending_tool_calls: Map.put(acc.pending_tool_calls, index, pending)}
  end

  # Streaming: argument fragment received, accumulate it
  defp accumulate_chunk(
         %Chunk{type: :tool_call_args, tool_call_index: index, tool_call_args_fragment: fragment},
         acc
       ) do
    case Map.get(acc.pending_tool_calls, index) do
      nil ->
        # This is a bug - we received arguments before tool_call_start
        raise ArgumentError,
              "Received tool_call_args for index #{index} but no tool_call_start was received. " <>
                "This indicates a bug in the streaming pipeline."

      pending ->
        updated = %{pending | args_fragments: pending.args_fragments ++ [fragment]}
        %{acc | pending_tool_calls: Map.put(acc.pending_tool_calls, index, updated)}
    end
  end

  # Non-streaming: complete tool call received
  defp accumulate_chunk(%Chunk{type: :tool_call_end, tool_call: tool_call}, acc) do
    %{acc | tool_calls: Map.put(acc.tool_calls, tool_call.id, tool_call)}
  end

  defp accumulate_chunk(%Chunk{type: :usage, usage: usage}, acc) do
    %{acc | usage: usage}
  end

  defp accumulate_chunk(%Chunk{type: :done, finish_reason: reason, metadata: meta}, acc) do
    %{acc | finish_reason: reason, metadata: Map.merge(acc.metadata, meta || %{})}
  end

  # Catch-all for unknown chunk types
  defp accumulate_chunk(_chunk, acc), do: acc

  # Finalize pending tool calls by joining accumulated argument fragments
  # NOTE: We do NOT fall back to "{}" on JSON parse failure - this masks issues
  # where the LLM generates malformed tool calls. Let the error surface at execution.
  defp finalize_pending_tool_calls(pending_map) do
    require Logger

    Map.new(pending_map, fn {_index, %{id: id, name: name, args_fragments: fragments}} ->
      args_json = IO.iodata_to_binary(fragments)

      # Log warning if arguments are empty or invalid JSON (helps debug LLM issues)
      case {args_json, Jason.decode(args_json)} do
        {"", _} ->
          Logger.warning(
            "Tool call #{name} (#{id}) has empty arguments - LLM may have failed to provide required parameters"
          )

        {_, {:error, _}} ->
          Logger.warning(
            "Tool call #{name} (#{id}) has invalid JSON arguments: #{inspect(args_json)}"
          )

        _ ->
          :ok
      end

      # Keep original args_json (even if empty/invalid) - don't mask with "{}"
      {id, %Swarm.ToolCall{id: id, name: name, arguments: args_json}}
    end)
  end

  defp build_reasoning_entry(text, meta, index) do
    # Merge provider metadata with text and index
    meta
    |> Map.put("text", text)
    |> Map.put("index", index)
  end
end
