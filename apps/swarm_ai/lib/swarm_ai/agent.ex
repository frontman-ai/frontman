defprotocol SwarmAi.Agent do
  @moduledoc """
  Protocol for defining agents in SwarmAi.

  Implement this protocol for your agent struct to define:
  - System prompt for the LLM
  - LLM client to use
  """

  @doc "Return the system prompt for this agent"
  @spec system_prompt(t) :: String.t()
  def system_prompt(agent)

  @doc "Return the LLM client for this agent"
  @spec llm(t) :: SwarmAi.LLM.t()
  def llm(agent)
end
