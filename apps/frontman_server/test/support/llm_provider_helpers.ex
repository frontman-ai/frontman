defmodule FrontmanServer.Testing.LLMProviderHelpers do
  @moduledoc false

  import Mox

  alias FrontmanServer.Tasks.Execution.LLMProviderMock

  def expect_llm_responses(responses) do
    {:ok, response_agent} = Agent.start_link(fn -> responses end)

    expect(LLMProviderMock, :stream_text, length(responses), fn _model, _messages, _opts ->
      response =
        Agent.get_and_update(response_agent, fn
          [response | rest] -> {response, rest}
          [] -> raise "unexpected LLM provider call"
        end)

      provider_response(response)
    end)
  end

  def expect_llm_response(response, count) do
    expect(LLMProviderMock, :stream_text, count, fn _model, _messages, _opts ->
      provider_response(response)
    end)
  end

  def stub_llm_response(response) do
    stub(LLMProviderMock, :stream_text, fn _model, _messages, _opts ->
      provider_response(response)
    end)
  end

  def provider_response({:tool_calls, tool_calls, content}) do
    {:ok, reqllm_tool_response(tool_calls, content)}
  end

  def provider_response({:error, reason}), do: {:error, reason}

  def provider_response({:stream_raise, message}) do
    {:ok,
     %{
       stream:
         Stream.resource(
           fn -> :init end,
           fn :init -> raise message end,
           fn _ -> :ok end
         ),
       cancel: fn -> :ok end
     }}
  end

  def provider_response({:delay, content, delay_ms}) when is_binary(content) do
    {:ok,
     %{
       stream:
         Stream.resource(
           fn -> :init end,
           fn
             :init ->
               Process.sleep(delay_ms)

               {
                 [
                   ReqLLM.StreamChunk.text(content),
                   ReqLLM.StreamChunk.meta(%{usage: %{input_tokens: 10, output_tokens: 5}}),
                   ReqLLM.StreamChunk.meta(%{finish_reason: :stop})
                 ],
                 :done
               }

             :done ->
               {:halt, :done}
           end,
           fn _ -> :ok end
         ),
       cancel: fn -> :ok end
     }}
  end

  def provider_response(content) when is_binary(content), do: {:ok, reqllm_response(content)}

  def reqllm_response(content) do
    %{
      stream: [
        ReqLLM.StreamChunk.text(content),
        ReqLLM.StreamChunk.meta(%{usage: %{input_tokens: 10, output_tokens: 5}}),
        ReqLLM.StreamChunk.meta(%{finish_reason: :stop})
      ],
      cancel: fn -> :ok end
    }
  end

  def reqllm_tool_response(tool_calls, content) do
    chunks =
      [ReqLLM.StreamChunk.text(content)] ++
        Enum.map(Enum.with_index(tool_calls), fn {tool_call, index} ->
          ReqLLM.StreamChunk.tool_call(tool_call.name, tool_call_args(tool_call), %{
            id: tool_call.id,
            index: index
          })
        end)

    %{
      stream:
        chunks ++
          [
            ReqLLM.StreamChunk.meta(%{usage: %{input_tokens: 10, output_tokens: 5}}),
            ReqLLM.StreamChunk.meta(%{finish_reason: :stop})
          ],
      cancel: fn -> :ok end
    }
  end

  defp tool_call_args(%SwarmAi.ToolCall{arguments: arguments}) when is_map(arguments),
    do: arguments

  defp tool_call_args(%SwarmAi.ToolCall{arguments: arguments}) when is_binary(arguments) do
    Jason.decode!(arguments)
  end

  defp tool_call_args(_tool_call), do: %{}
end
