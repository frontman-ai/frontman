defmodule Swarm.LLM.Response do
  @moduledoc """
  Normalized response from an LLM call.

  Adapters convert provider-specific responses to this canonical format.
  Can be built from a stream via `from_stream/1`.
  """
  use TypedStruct

  alias Swarm.LLM.{Chunk, Usage}
  alias Swarm.ToolCall

  @type finish_reason :: :stop | :tool_calls | :length | :error | nil

  typedstruct do
    field :content, String.t()
    field :finish_reason, finish_reason(), default: :stop
    field :tool_calls, [Swarm.ToolCall.t()], default: []
    field :usage, Usage.t()
    field :raw, term()
  end

  @spec has_tool_calls?(t()) :: boolean()
  def has_tool_calls?(%__MODULE__{tool_calls: []}), do: false
  def has_tool_calls?(%__MODULE__{tool_calls: _}), do: true

  @doc """
  Build a Response from a stream of chunks.

  This is the batch-style convenience for when you don't need real-time
  token emission. Consumes the entire stream and returns the collected response.
  """
  @spec from_stream(Enumerable.t(Chunk.t())) :: t()
  def from_stream(stream) do
    acc = %{content: [], tool_calls: %{}, usage: nil, finish_reason: :stop}

    result = Enum.reduce(stream, acc, &accumulate_chunk/2)

    %__MODULE__{
      content: IO.iodata_to_binary(result.content),
      tool_calls: build_tool_calls(result.tool_calls),
      usage: result.usage,
      finish_reason: result.finish_reason
    }
  end

  defp accumulate_chunk(%Chunk{type: :token, text: text}, acc) do
    %{acc | content: [acc.content, text]}
  end

  defp accumulate_chunk(%Chunk{type: :thinking}, acc), do: acc

  defp accumulate_chunk(%Chunk{type: :tool_call_start} = chunk, acc) do
    tc_state = %{
      id: chunk.tool_call_id,
      name: chunk.tool_call_name,
      arguments_fragments: []
    }

    %{acc | tool_calls: Map.put(acc.tool_calls, chunk.tool_call_id, tc_state)}
  end

  defp accumulate_chunk(%Chunk{type: :tool_call_delta} = chunk, acc) do
    update_fn = fn tc_state ->
      %{
        tc_state
        | arguments_fragments: [tc_state.arguments_fragments, chunk.tool_call_arguments_fragment]
      }
    end

    %{acc | tool_calls: Map.update!(acc.tool_calls, chunk.tool_call_id, update_fn)}
  end

  defp accumulate_chunk(%Chunk{type: :tool_call_end, tool_call: tool_call}, acc) do
    tc_state = %{id: tool_call.id, name: tool_call.name, arguments: tool_call.arguments, complete: true}
    %{acc | tool_calls: Map.put(acc.tool_calls, tool_call.id, tc_state)}
  end

  defp accumulate_chunk(%Chunk{type: :usage, usage: usage}, acc) do
    %{acc | usage: usage}
  end

  defp accumulate_chunk(%Chunk{type: :done, finish_reason: reason}, acc) do
    %{acc | finish_reason: reason}
  end

  defp build_tool_calls(tool_calls_map) do
    tool_calls_map
    |> Map.values()
    |> Enum.map(&finalize_tool_call/1)
  end

  defp finalize_tool_call(%{complete: true} = tc) do
    %ToolCall{id: tc.id, name: tc.name, arguments: tc.arguments}
  end

  defp finalize_tool_call(tc) do
    arguments = IO.iodata_to_binary(tc.arguments_fragments)
    %ToolCall{id: tc.id, name: tc.name, arguments: arguments}
  end
end
