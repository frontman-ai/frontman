defprotocol Swarm.Agent do
  @moduledoc """
  Protocol for defining agents in the Swarm framework.

  Implement this protocol for your agent struct to define:
  - System prompt for the LLM
  - Initial state and available tools
  - Custom termination logic (optional)
  - LLM client to use
  """

  @doc "Return the system prompt for this agent"
  @spec system_prompt(t) :: String.t()
  def system_prompt(agent)

  @doc "Initialize agent state and tools"
  @spec init(t) :: {:ok, state :: term(), tools :: [Swarm.Tool.t()]}
  def init(agent)

  @doc "Check if loop should terminate early. Return false to use default behavior."
  @spec should_terminate?(t, Swarm.Loop.t(), state :: term()) :: boolean()
  def should_terminate?(agent, loop, state)

  @doc "Return the LLM client for this agent"
  @spec llm(t) :: Swarm.LLM.t()
  def llm(agent)
end

defimpl Swarm.Agent, for: Any do
  defmacro __deriving__(module, _struct, _opts) do
    quote do
      defimpl Swarm.Agent, for: unquote(module) do
        def system_prompt(_), do: raise("#{unquote(module)} must implement system_prompt/1")
        def init(_), do: raise("#{unquote(module)} must implement init/1")
        def should_terminate?(_, _, _), do: false
        def llm(_), do: raise("#{unquote(module)} must implement llm/1")
      end
    end
  end

  def system_prompt(v), do: raise(Protocol.UndefinedError, protocol: Swarm.Agent, value: v)
  def init(v), do: raise(Protocol.UndefinedError, protocol: Swarm.Agent, value: v)
  def should_terminate?(_, _, _), do: false
  def llm(v), do: raise(Protocol.UndefinedError, protocol: Swarm.Agent, value: v)
end
