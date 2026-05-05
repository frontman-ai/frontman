defmodule FrontmanServer.Testing.LLMProviderStub do
  @moduledoc false

  @behaviour FrontmanServer.Tasks.Execution.LLMProvider

  @impl true
  def stream_text(_model, _messages, _opts) do
    {:ok,
     %{
       stream: [
         ReqLLM.StreamChunk.text("Test response"),
         ReqLLM.StreamChunk.meta(%{usage: %{input_tokens: 10, output_tokens: 5}}),
         ReqLLM.StreamChunk.meta(%{finish_reason: :stop})
       ],
       cancel: fn -> :ok end
     }}
  end
end
