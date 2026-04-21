defprotocol SwarmAi.LLM do
  @moduledoc """
  Protocol for LLM integration.

  Implement this protocol for your LLM client struct to provide streaming
  responses to the SwarmAi execution loop. The only required function is
  `stream/3`, which returns a lazy enumerable of `ReqLLM.StreamChunk.t()`.

  Batch-style responses can be built from the stream via `SwarmAi.LLM.Response.from_stream/1`.
  """

  @doc """
  Stream LLM response as chunks.

  This is the primitive operation - batch responses are built via
  Response.from_stream/1. Returns a lazy enumerable of ReqLLM.StreamChunk.t().
  """
  @spec stream(t, messages :: [SwarmAi.Message.t()], opts :: keyword()) ::
          {:ok, Enumerable.t(ReqLLM.StreamChunk.t())} | {:error, term()}
  def stream(client, messages, opts)
end
