defmodule FrontmanServer.Test.Fixtures.ReqLLMResponses do
  @moduledoc false

  alias ReqLLM.StreamChunk

  def response({:tool_calls, tool_calls, content}) do
    [StreamChunk.text(content) | Enum.map(Enum.with_index(tool_calls), &tool_call_chunk/1)]
    |> response()
  end

  def response({:error, reason}), do: {:error, reason}
  def response({:raise, message}), do: raise(message)
  def response({:exit, reason}), do: exit(reason)

  def response({:stream_raise, message}),
    do: {:ok, stream(Stream.map([:ok], fn _ -> raise message end))}

  def response({:delay, content, delay_ms}) do
    Process.sleep(delay_ms)
    response(content)
  end

  def response(content) when is_binary(content), do: [StreamChunk.text(content)] |> response()
  def response(chunks) when is_list(chunks), do: {:ok, stream(chunks ++ meta_chunks())}

  defp stream(chunks), do: %{stream: chunks, cancel: fn -> :ok end}

  defp meta_chunks do
    [
      StreamChunk.meta(%{usage: %{input_tokens: 10, output_tokens: 5}}),
      StreamChunk.meta(%{finish_reason: :stop})
    ]
  end

  defp tool_call_chunk({tool_call, index}) do
    StreamChunk.tool_call(tool_call.name, tool_call_args(tool_call), %{
      id: tool_call.id,
      index: index
    })
  end

  defp tool_call_args(%{arguments: arguments}) when is_map(arguments), do: arguments

  defp tool_call_args(%{arguments: arguments}) when is_binary(arguments),
    do: Jason.decode!(arguments)
end
