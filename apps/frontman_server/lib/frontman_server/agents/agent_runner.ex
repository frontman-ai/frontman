defmodule FrontmanServer.Agents.AgentRunner do
  @moduledoc """
  Runs Swarm agents with MCP tool execution.

  Uses `Swarm.run_blocking/3` with `ToolExecutor` for tool execution.
  """

  alias FrontmanServer.Agents.{LLMClient, ToolExecutor}

  defmodule Agent do
    @moduledoc false
    defstruct [:system_prompt, :llm]
  end

  defimpl Swarm.Agent, for: FrontmanServer.Agents.AgentRunner.Agent do
    def system_prompt(%{system_prompt: prompt}), do: prompt
    def llm(%{llm: llm}), do: llm
    def init(_), do: {:ok, %{}, []}
    def should_terminate?(_, _, _), do: false
  end

  @doc """
  Executes an agent with MCP tool execution.

  ## Options
  - `:tools` - List of Swarm.Tool definitions
  - `:model` - LLM model spec
  - `:messages` - List of Swarm.Message.t() for the conversation (supports multimodal)
  """
  @spec execute(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def execute(task_id, agent_id, system_prompt, opts \\ []) do
    tools = Keyword.get(opts, :tools, [])
    model = Keyword.get(opts, :model)
    messages = Keyword.get(opts, :messages, [])

    llm_opts = if model, do: [model: model, tools: tools], else: [tools: tools]
    llm = LLMClient.new(llm_opts)
    agent = %Agent{system_prompt: system_prompt, llm: llm}

    tool_executor = ToolExecutor.make_executor(task_id, agent_id)
    Swarm.run_blocking(agent, messages, tool_executor)
  end
end
