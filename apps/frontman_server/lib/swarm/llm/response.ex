defmodule Swarm.LLM.Response do
  @moduledoc """
  Normalized response from an LLM call.

  Adapters convert provider-specific responses to this canonical format.
  Can be built from a stream via `from_stream/1`.
  """
  use TypedStruct

  alias Swarm.LLM.{Chunk, Usage}

  @type finish_reason :: :stop | :tool_calls | :length | :error | nil

  typedstruct do
    field :content, String.t()
    field :reasoning_details, [map()], default: []
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
    acc = %{content: [], reasoning_details: [], tool_calls: %{}, usage: nil, finish_reason: :stop}

    result = Enum.reduce(stream, acc, &accumulate_chunk/2)

    %__MODULE__{
      content: IO.iodata_to_binary(result.content),
      reasoning_details: result.reasoning_details,
      tool_calls: build_tool_calls(result.tool_calls),
      usage: result.usage,
      finish_reason: result.finish_reason
    }
  end

  defp accumulate_chunk(%Chunk{type: :token, text: text}, acc) do
    %{acc | content: [acc.content, text]}
  end

  defp accumulate_chunk(%Chunk{type: :thinking, text: text, metadata: meta}, acc) do
    entry = build_reasoning_entry(text, meta, length(acc.reasoning_details))
    %{acc | reasoning_details: acc.reasoning_details ++ [entry]}
  end

  defp accumulate_chunk(%Chunk{type: :tool_call_end, tool_call: tool_call}, acc) do
    %{acc | tool_calls: Map.put(acc.tool_calls, tool_call.id, tool_call)}
  end

  defp accumulate_chunk(%Chunk{type: :usage, usage: usage}, acc) do
    %{acc | usage: usage}
  end

  defp accumulate_chunk(%Chunk{type: :done, finish_reason: reason}, acc) do
    %{acc | finish_reason: reason}
  end

  defp build_tool_calls(tool_calls_map) do
    Map.values(tool_calls_map)
  end

  defp build_reasoning_entry(text, meta, index) do
    # Merge provider metadata with text and index
    meta
    |> Map.put("text", text)
    |> Map.put("index", index)
  end
end
