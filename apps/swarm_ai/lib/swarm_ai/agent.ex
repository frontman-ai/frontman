defprotocol SwarmAi.Agent do
  @moduledoc """
  Runnable agent protocol.
  """

  @type tool_executor :: %{
          required(:build) => ([SwarmAi.ToolCall.t()] -> [SwarmAi.ToolExecution.t()]),
          required(:execution_mode) => :parallel | :serial
        }

  @doc "Returns a stable string id for this agent."
  @spec id(t) :: String.t()
  def id(agent)

  @doc "Return messages for this run."
  @spec messages(t) :: SwarmAi.Message.input()
  def messages(agent)

  @doc "Return dispatcher-only context for this run."
  @spec context(t) :: map()
  def context(agent)

  @doc "Return tool execution builder and execution mode for this run."
  @spec tool_executor(t) :: tool_executor()
  def tool_executor(agent)

  @doc "Return the system prompt for this run."
  @spec system_prompt(t) :: String.t()
  def system_prompt(agent)

  @doc "Return the LLM client for this run."
  @spec llm(t) :: SwarmAi.LLM.t()
  def llm(agent)
end
