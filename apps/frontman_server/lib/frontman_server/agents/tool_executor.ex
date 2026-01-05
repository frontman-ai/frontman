defmodule FrontmanServer.Agents.ToolExecutor do
  @moduledoc """
  Unified tool execution for both backend and MCP tools.

  Backend tools are executed directly server-side.
  MCP tools use Registry-based result routing to wait for client execution.
  """

  require Logger

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools
  alias FrontmanServer.Tools.Backend
  alias FrontmanServer.Observability.TelemetryEvents

  @tool_timeout_ms 60_000

  @doc """
  Returns a tool executor function for use with Swarm execution.

  The returned function:
  1. Tries to execute as a backend tool first
  2. Falls back to MCP routing if not a backend tool

  ## Options

  - `:on_tool_call` - Optional callback `fn(agent_id, tool_call) -> :ok` called before execution

  ## Examples

      executor = ToolExecutor.make_executor(task_id, agent_id)
      Swarm.run_blocking(agent, messages, executor)

      # With callback
      executor = ToolExecutor.make_executor(task_id, agent_id,
        on_tool_call: fn _agent_id, tc -> IO.puts("Calling \#{tc.name}") end
      )
  """
  @spec make_executor(String.t(), String.t(), keyword()) ::
          (Swarm.ToolCall.t() -> {:ok, String.t()} | {:error, String.t()})
  def make_executor(task_id, agent_id, opts \\ []) do
    on_tool_call = Keyword.get(opts, :on_tool_call, fn _agent_id, _tc -> :ok end)

    fn tool_call ->
      # For MCP tools, register BEFORE broadcasting to prevent race condition.
      # If we broadcast first, fast MCP responses could arrive before we're
      # ready to receive them.
      maybe_register_mcp_tool(tool_call)

      on_tool_call.(agent_id, tool_call)
      execute(tool_call, task_id, agent_id)
    end
  end

  defp maybe_register_mcp_tool(tool_call) do
    case Tools.find_tool(tool_call.name) do
      {:ok, _module} ->
        :ok

      :not_found ->
        Registry.register(FrontmanServer.AgentRegistry, {:tool_call, tool_call.id}, %{
          caller_pid: self()
        })
    end
  end

  @doc """
  Execute a single tool, trying backend first then MCP.
  """
  @spec execute(Swarm.ToolCall.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def execute(tool_call, task_id, agent_id) do
    case Tools.find_tool(tool_call.name) do
      {:ok, module} ->
        execute_backend_tool(module, tool_call, task_id, agent_id)

      :not_found ->
        execute_mcp_tool(tool_call, task_id, agent_id)
    end
  end

  # --- Backend Tool Execution ---

  defp execute_backend_tool(module, tool_call, task_id, agent_id) do
    Logger.info("ToolExecutor: Executing backend tool #{tool_call.name}")

    TelemetryEvents.tool_start(
      tool_call.id,
      tool_call.name,
      agent_id,
      task_id,
      tool_call.arguments
    )

    case Tasks.get_task(task_id) do
      {:ok, task} ->
        context = %Backend.Context{task: task, agent_id: agent_id}
        args = parse_arguments(tool_call.arguments)

        result = module.execute(args, context)

        case result do
          {:ok, value} ->
            TelemetryEvents.tool_stop(tool_call.id, status: "success")
            encoded = encode_result(value)

            # Store tool result for interaction history and UI notification
            Tasks.add_tool_result(
              task_id,
              agent_id,
              %{id: tool_call.id, name: tool_call.name},
              value,
              false
            )

            {:ok, encoded}

          {:error, reason} ->
            TelemetryEvents.tool_stop(tool_call.id, status: "error", error: reason)

            # Store error result for interaction history and UI notification
            Tasks.add_tool_result(
              task_id,
              agent_id,
              %{id: tool_call.id, name: tool_call.name},
              reason,
              true
            )

            {:error, reason}
        end

      {:error, :not_found} ->
        TelemetryEvents.tool_stop(tool_call.id, status: "error", error: "Task not found")
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

  defp execute_mcp_tool(tool_call, _task_id, _agent_id) do
    Logger.info("ToolExecutor: Routing to MCP tool #{tool_call.name}")

    # Registration already happened in maybe_register_mcp_tool before broadcast
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
