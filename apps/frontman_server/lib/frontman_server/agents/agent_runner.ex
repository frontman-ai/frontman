defmodule FrontmanServer.Agents.AgentRunner do
  @moduledoc """
  Runs Swarm agents with concurrent tool execution for MCP integration.
  """

  require Logger

  alias FrontmanServer.Agents.LLMClient
  alias FrontmanServer.Tasks
  alias Swarm.ToolResult

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
  Executes an agent with concurrent tool execution.

  ## Options
  - `:tools` - List of ReqLLM.Tool definitions
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

    run_agent(agent, messages, task_id, agent_id)
  end

  defp run_agent(agent, messages, task_id, agent_id) do
    case Swarm.run(agent, messages) do
      {:completed, loop} ->
        {:ok, loop.result}

      {:tool_calls, loop, tool_calls} ->
        results = execute_tools_concurrent(tool_calls, task_id, agent_id)
        continue_agent(loop, results, task_id, agent_id)

      {:error, loop} ->
        {:error, loop.error}
    end
  end

  defp continue_agent(loop, results, task_id, agent_id) do
    case Swarm.continue(loop, results) do
      {:completed, loop} ->
        {:ok, loop.result}

      {:tool_calls, loop, tool_calls} ->
        results = execute_tools_concurrent(tool_calls, task_id, agent_id)
        continue_agent(loop, results, task_id, agent_id)

      {:error, loop} ->
        {:error, loop.error}
    end
  end

  defp execute_tools_concurrent(tool_calls, task_id, agent_id) do
    tool_calls
    |> Enum.map(fn tc ->
      Task.async(fn ->
        {tc, execute_tool_blocking(tc, task_id, agent_id)}
      end)
    end)
    |> Task.await_many(@tool_timeout_ms)
    |> Enum.map(fn {tc, result} ->
      case result do
        {:ok, content} ->
          %ToolResult{id: tc.id, content: content, is_error: false}

        {:error, reason} ->
          %ToolResult{id: tc.id, content: to_string(reason), is_error: true}
      end
    end)
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
