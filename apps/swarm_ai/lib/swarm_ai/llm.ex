defprotocol SwarmAi.LLM do
  def stream(client, messages, opts)
end
