defmodule FrontmanServer.Agents.ToolExecutor do
  @moduledoc """
  Unified tool execution for both backend and MCP tools.

  Backend tools are executed directly server-side.
  MCP tools use Registry-based result routing to wait for client execution.

  ## MCP Tool Routing

  For MCP tools, the executor handles the complete routing flow:
  1. Registers in AgentRegistry (for receiving response)
  2. Publishes interaction via Tasks.add_tool_call (for TaskChannel routing)
  3. Waits for client response via receive

  This ensures MCP tools work correctly for both main agents and sub-agents
  without requiring callers to handle interaction publishing.

  ## Telemetry

  Tool execution telemetry is handled by Swarm. This module focuses only
  on executing tools.
  """

  require Logger

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.Backend

  @tool_timeout_ms 60_000

  @doc """
  Returns a tool executor function for use with Swarm execution.

  The returned function:
  1. Tries to execute as a backend tool first
  2. Falls back to MCP routing if not a backend tool

  For MCP tools, the executor automatically publishes interactions to enable
  routing through TaskChannel. Callers don't need to handle this.

  ## Examples

      executor = ToolExecutor.make_executor(task_id)
      Swarm.run_blocking(agent, messages, executor)
  """
  @spec make_executor(String.t()) ::
          (Swarm.ToolCall.t() -> {:ok, String.t()} | {:error, String.t()})
  def make_executor(task_id) do
    fn tool_call ->
      is_mcp_tool = register_if_mcp_tool(tool_call)

      # For MCP tools, publish interaction so TaskChannel can route to client.
      # This must happen AFTER registration to prevent race conditions.
      if is_mcp_tool do
        publish_mcp_tool_call(task_id, tool_call)
      end

      execute(tool_call, task_id)
    end
  end

  # Returns true if this is an MCP tool (registered for response), false for backend tools
  defp register_if_mcp_tool(tool_call) do
    case Tools.find_tool(tool_call.name) do
      {:ok, _module} ->
        false

      :not_found ->
        Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call.id}, %{
          caller_pid: self()
        })

        true
    end
  end

  defp publish_mcp_tool_call(task_id, tool_call) do
    reqllm_tc = to_reqllm_tool_call(tool_call)

    case Tasks.add_tool_call(task_id, reqllm_tc) do
      {:ok, _interaction} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "ToolExecutor: Failed to publish MCP tool call #{tool_call.id}: #{inspect(reason)}"
        )

        raise "Failed to publish MCP tool call: #{inspect(reason)}"
    end
  end

  defp to_reqllm_tool_call(%Swarm.ToolCall{} = tc) do
    ReqLLM.ToolCall.new(tc.id, tc.name, tc.arguments)
  end

  @doc """
  Execute a single tool, trying backend first then MCP.
  """
  @spec execute(Swarm.ToolCall.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def execute(tool_call, task_id) do
    case Tools.find_tool(tool_call.name) do
      {:ok, module} ->
        execute_backend_tool(module, tool_call, task_id)

      :not_found ->
        execute_mcp_tool(tool_call, task_id)
    end
  end

  # --- Backend Tool Execution ---

  defp execute_backend_tool(module, tool_call, task_id) do
    Logger.info("ToolExecutor: Executing backend tool #{tool_call.name}")

    case Tasks.get_task(task_id) do
      {:ok, task} ->
        context = %Backend.Context{task: task}
        args = parse_arguments(tool_call.arguments)

        result = module.execute(args, context)

        case result do
          {:ok, value} ->
            encoded = encode_result(value)

            # Store tool result for interaction history and UI notification
            Tasks.add_tool_result(
              task_id,
              %{id: tool_call.id, name: tool_call.name},
              value,
              false
            )

            {:ok, encoded}

          {:error, reason} ->
            # Store error result for interaction history and UI notification
            Tasks.add_tool_result(
              task_id,
              %{id: tool_call.id, name: tool_call.name},
              reason,
              true
            )

            {:error, reason}
        end

      {:error, :not_found} ->
        {:error, "Task not found"}
    end
  end

  defp parse_arguments(arguments) when is_binary(arguments) do
    case Jason.decode(arguments) do
      {:ok, decoded} -> decoded
      {:error, _} -> %{}
    end
  end

  defp parse_arguments(arguments) when is_map(arguments), do: arguments
  defp parse_arguments(_), do: %{}

  defp encode_result(value) when is_binary(value), do: value
  defp encode_result(value), do: Jason.encode!(value)

  # --- MCP Tool Execution ---

  defp execute_mcp_tool(tool_call, _task_id) do
    Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

    # Registration already happened in register_if_mcp_tool before broadcast
    tool_call_id = tool_call.id

    receive do
      {:tool_result, ^tool_call_id, content, is_error} ->
        Registry.unregister(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id})
        if is_error, do: {:error, content}, else: {:ok, content}
    after
      @tool_timeout_ms ->
        Registry.unregister(FrontmanServer.AgentRegistry, {:tool_call, tool_call_id})
        {:error, "Tool timeout: #{tool_call.name}"}
    end
  end
end
