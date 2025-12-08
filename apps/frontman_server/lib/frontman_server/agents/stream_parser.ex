defmodule FrontmanServer.Agents.StreamParser do
  @moduledoc """
  Parses LLM stream responses into domain types.

  This module serves as the boundary between raw stream data
  and typed domain structs, following "parse, don't validate".
  All stream chunk parsing should go through this module to
  ensure proper type conversion at the boundary.
  """

  alias ReqLLM.ToolCall

  @doc """
  Extracts tool calls from stream chunks, returning properly typed ToolCall structs.

  Handles both inline arguments and streamed argument fragments (for providers
  that stream tool call arguments separately).
  """
  @spec extract_tool_calls([map()]) :: [ToolCall.t()]
  def extract_tool_calls(chunks) do
    raw_calls = extract_raw_tool_calls(chunks)
    arg_fragments = collect_argument_fragments(chunks)

    Enum.map(raw_calls, fn call ->
      args = resolve_arguments(call, arg_fragments)
      tool_call_from_raw(call.id, call.name, args)
    end)
  end

  @doc """
  Creates a ToolCall struct from raw data with proper JSON encoding.

  This is the single point of conversion from untyped data to ToolCall.
  Arguments are JSON-encoded if they're a map.
  """
  @spec tool_call_from_raw(String.t() | nil, String.t(), map() | String.t()) :: ToolCall.t()
  def tool_call_from_raw(id, name, arguments) do
    args_json = if is_binary(arguments), do: arguments, else: Jason.encode!(arguments)
    ToolCall.new(id, name, args_json)
  end

  # -- Private Helpers --

  defp extract_raw_tool_calls(chunks) do
    chunks
    |> Enum.filter(&(&1.type == :tool_call))
    |> Enum.map(fn chunk ->
      %{
        id: Map.get(chunk.metadata, :id) || generate_id(),
        name: chunk.name,
        arguments: chunk.arguments || %{},
        index: Map.get(chunk.metadata, :index, 0)
      }
    end)
  end

  defp collect_argument_fragments(chunks) do
    chunks
    |> Enum.filter(fn
      %{type: :meta, metadata: %{tool_call_args: _}} -> true
      _ -> false
    end)
    |> Enum.group_by(& &1.metadata.tool_call_args.index)
    |> Map.new(fn {index, fragments} ->
      json = fragments |> Enum.map_join("", & &1.metadata.tool_call_args.fragment)
      {index, json}
    end)
  end

  defp resolve_arguments(call, arg_fragments) do
    case Map.get(arg_fragments, call.index) do
      nil ->
        call.arguments

      json ->
        case Jason.decode(json) do
          {:ok, args} -> args
          {:error, _} -> call.arguments
        end
    end
  end

  defp generate_id do
    "call_#{:erlang.unique_integer([:positive])}"
  end
end
