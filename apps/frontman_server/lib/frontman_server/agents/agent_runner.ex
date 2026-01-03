defmodule FrontmanServer.Agents.AgentRunner do
  @moduledoc """
  Runs Swarm agents with blocking tool execution for MCP integration.
  """

  require Logger

  alias FrontmanServer.Agents.LLMClient
  alias FrontmanServer.Tasks

  @tool_timeout_ms 60_000

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
  Executes an agent synchronously with blocking tool calls.

  ## Options
  - `:tools` - List of ReqLLM.Tool definitions
  - `:model` - LLM model spec
  - `:max_steps` - Max LLM iterations (default: 10)
  - `:messages` - List of Swarm.Message.t() for the conversation (supports multimodal)
  """
  @spec execute(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def execute(task_id, agent_id, system_prompt, opts \\ []) do
    tools = Keyword.get(opts, :tools, [])
    model = Keyword.get(opts, :model)
    max_steps = Keyword.get(opts, :max_steps, 10)
    messages = Keyword.get(opts, :messages, [])

    llm_opts = if model, do: [model: model, tools: tools], else: [tools: tools]
    llm = LLMClient.new(llm_opts)
    agent = %Agent{system_prompt: system_prompt, llm: llm}

    callbacks = %{
      tool_handler: fn tool_call ->
        execute_tool_blocking(tool_call, task_id, agent_id)
      end
    }

    Swarm.run(agent, messages, callbacks, max_steps: max_steps)
  end

  defp execute_tool_blocking(tool_call, task_id, agent_id) do
    ref = make_ref()

    Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call.id}, %{
      executor: :agent_runner,
      caller_ref: ref,
      caller_pid: self()
    })

    Tasks.add_tool_call(task_id, agent_id, to_req_llm_tool_call(tool_call))

    receive do
      {:tool_result, ^ref, content, is_error} ->
        Registry.unregister(FrontmanServer.AgentRegistry, {:tool_call, tool_call.id})
        if is_error, do: {:error, content}, else: {:ok, content}
    after
      @tool_timeout_ms ->
        Registry.unregister(FrontmanServer.AgentRegistry, {:tool_call, tool_call.id})
        {:error, "Tool timeout: #{tool_call.name}"}
    end
  end

  defp to_req_llm_tool_call(%Swarm.ToolCall{} = tc) do
    ReqLLM.ToolCall.new(tc.id, tc.name, tc.arguments)
  end
end
