defprotocol SwarmAi.LLM do
  @doc """
  Stream LLM response as chunks.

  This is the primitive operation - batch responses are built via
  Response.from_stream/1. Returns a lazy enumerable of Chunk.t().
  """
  @spec stream(t, messages :: [SwarmAi.Message.t()], opts :: keyword()) ::
          {:ok, Enumerable.t(SwarmAi.LLM.Chunk.t())} | {:error, term()}
  def stream(client, messages, opts)
end
