defmodule FrontmanServer.Agents.ToolExecutor do
  @moduledoc """
  MCP tool execution with Registry-based result routing.

  Provides blocking tool execution that integrates with the FrontmanServer
  infrastructure (Registry for result routing, Tasks for MCP notification).
  """

  alias FrontmanServer.Tasks

  @tool_timeout_ms 60_000

  @doc """
  Returns a tool executor function for use with `Swarm.run_blocking/3`.

  The returned function executes tools by:
  1. Registering for result routing via `FrontmanServer.AgentRegistry`
  2. Notifying the MCP system via `Tasks.add_tool_call`
  3. Blocking until the result arrives

  ## Examples

      executor = ToolExecutor.make_executor(task_id, agent_id)
      Swarm.run_blocking(agent, messages, executor)
  """
  @spec make_executor(String.t(), String.t()) ::
          (Swarm.ToolCall.t() -> {:ok, String.t()} | {:error, String.t()})
  def make_executor(task_id, agent_id) do
    fn tool_call -> execute_blocking(tool_call, task_id, agent_id) end
  end

  @doc """
  Execute a single tool, blocking until the result arrives.

  Registers the tool call in the AgentRegistry and notifies the MCP system.
  Blocks until a result message is received or timeout occurs.
  """
  @spec execute_blocking(Swarm.ToolCall.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def execute_blocking(tool_call, task_id, agent_id) do
    ref = make_ref()

    Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call.id}, %{
      executor: :tool_executor,
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
