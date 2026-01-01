defprotocol Swarm.LLM do
  @doc "Call the LLM with messages and optional tools"
  @spec call(t, messages :: [map()], opts :: keyword()) ::
          {:ok, Swarm.LLM.Response.t()} | {:error, term()}
  def call(client, messages, args)
end
