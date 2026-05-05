defmodule FrontmanServer.Testing.LLMProviderHelpers do
  @moduledoc false

  import Mox

  alias FrontmanServer.Tasks.Execution.LLMProviderMock
  alias ReqLLM.StreamChunk

  def expect_llm_responses(responses) do
    Mox.verify_on_exit!(%{})

    Enum.each(responses, fn response ->
      expect(LLMProviderMock, :stream_text, fn _model, _messages, _opts -> response(response) end)
    end)
  end

  def stub_llm_response(response) do
    stub(LLMProviderMock, :stream_text, fn _model, _messages, _opts -> response(response) end)
  end

  defp response({:tool_calls, tool_calls, content}) do
    chunks =
      [StreamChunk.text(content)] ++
        Enum.map(Enum.with_index(tool_calls), fn {tool_call, index} ->
          StreamChunk.tool_call(tool_call.name, tool_call_args(tool_call), %{
            id: tool_call.id,
            index: index
          })
        end)

    {:ok, reqllm_response(chunks)}
  end

  defp response({:error, reason}), do: {:error, reason}
  defp response({:raise, message}), do: raise(message)
  defp response({:exit, reason}), do: exit(reason)

  defp response({:stream_raise, message}) do
    {:ok, %{stream: Stream.map([:ok], fn _ -> raise message end), cancel: fn -> :ok end}}
  end

  defp response({:delay, content, delay_ms}) when is_binary(content) do
    Process.sleep(delay_ms)
    response(content)
  end

  defp response(content) when is_binary(content),
    do: {:ok, reqllm_response([StreamChunk.text(content)])}

  defp reqllm_response(chunks) do
    %{
      stream:
        chunks ++
          [
            StreamChunk.meta(%{usage: %{input_tokens: 10, output_tokens: 5}}),
            StreamChunk.meta(%{finish_reason: :stop})
          ],
      cancel: fn -> :ok end
    }
  end

  defp tool_call_args(%{arguments: arguments}) when is_map(arguments), do: arguments

  defp tool_call_args(%{arguments: arguments}) when is_binary(arguments),
    do: Jason.decode!(arguments)
end
